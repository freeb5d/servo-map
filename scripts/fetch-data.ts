/**
 * 独立数据抓取脚本 — 在 GitHub Actions 中运行
 *
 * 复用 worker 的 state adapters 抓取油价数据（单一真相来源），
 * 然后通过 Cloudflare KV REST API 写入。adapters 在运行时只依赖
 * 全局 fetch / crypto，对 @servo-map/shared 全是 type-only import。
 *
 * 环境变量:
 *   NSW_API_KEY, NSW_API_AUTH — NSW FuelCheck API 认证
 *   QLD_API_TOKEN — QLD Fuel Prices API token
 *   CF_ACCOUNT_ID, CF_API_TOKEN, CF_KV_NAMESPACE_ID — Cloudflare KV 写入
 *   D1_PRICES_DATABASE_ID — servo-map-prices D1（决策 0006）；未设置时跳过 D1 同步
 */

import type {
  Station,
  AustralianState,
  StateMetadata,
  PriceSnapshot,
} from "@servo-map/shared";
import { adapters } from "../packages/worker/src/adapters/index";
import { KV_KEYS } from "../packages/worker/src/kv/keys";
import {
  computeDailySnapshots,
  mergeDailySnapshots,
  utcDate,
} from "../packages/worker/src/utils/price-history";
import type { Env } from "../packages/worker/src/env";
import {
  recordIngestRuns,
  syncStatePrices,
  type IngestRunRecord,
} from "../packages/worker/src/prices-db/sync";
import { d1Executor } from "./d1-rest";

// 当某州本次抓取数量低于上次的该比例时，跳过覆盖以保护 KV 中的健康数据
const MIN_RETENTION_RATIO = 0.5;
// 低于此基数的州不触发护栏（新州 / 极小州的正常波动）
const RETENTION_GUARD_FLOOR = 20;

// ── 环境变量 ──

function requireEnv(name: string): string {
  const val = process.env[name];
  if (!val) throw new Error(`Missing env: ${name}`);
  return val;
}

/** 为 adapters 构造 env（KV binding 不会被 adapters 使用，仅读取 secrets） */
function buildAdapterEnv(): Env {
  return {
    NSW_API_KEY: requireEnv("NSW_API_KEY"),
    NSW_API_AUTH: requireEnv("NSW_API_AUTH"),
    QLD_API_TOKEN: process.env.QLD_API_TOKEN ?? "",
  } as unknown as Env;
}

// ── Cloudflare KV REST API ──

async function kvPut(key: string, value: string, retries = 3): Promise<void> {
  const accountId = requireEnv("CF_ACCOUNT_ID");
  const namespaceId = requireEnv("CF_KV_NAMESPACE_ID");
  const token = requireEnv("CF_API_TOKEN");

  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/storage/kv/namespaces/${namespaceId}/values/${encodeURIComponent(key)}`;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const res = await fetch(url, {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}` },
      body: value,
    });
    if (res.ok) return;
    if (res.status === 429 && attempt < retries) {
      // Rate limited — 等待后重试
      await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
      continue;
    }
    const body = await res.text().catch(() => "");
    throw new Error(`KV PUT ${key} failed: ${res.status} — ${body}`);
  }
}

async function kvGet(key: string): Promise<string | null> {
  const accountId = requireEnv("CF_ACCOUNT_ID");
  const namespaceId = requireEnv("CF_KV_NAMESPACE_ID");
  const token = requireEnv("CF_API_TOKEN");

  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/storage/kv/namespaces/${namespaceId}/values/${encodeURIComponent(key)}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) return null;
  return res.text();
}

// ── 主流程 ──

async function main() {
  console.log("[fetch-data] Starting...");

  // 并行调用所有 adapter，互不阻塞（一个失败不影响其他）
  const env = buildAdapterEnv();
  const results = await Promise.allSettled(
    adapters.map((a) => a.fetchStations(env)),
  );

  const runAt = new Date();
  // 每州本轮结果，写入 D1 ingest_runs —— 断档与失败事后可查
  const runRecords: IngestRunRecord[] = [];

  const allStations: Station[] = [];
  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    const label = adapters[i].states.join("/").toUpperCase();
    if (r.status === "fulfilled") {
      console.log(`[fetch-data] ${label}: ${r.value.length} stations`);
      allStations.push(...r.value);
    } else {
      console.error(`[fetch-data] ${label}: FAILED —`, r.reason);
      const detail = String(r.reason).slice(0, 500);
      for (const state of adapters[i].states) {
        runRecords.push({ state, status: "failed", stationCount: 0, rowsWritten: 0, detail });
      }
    }
  }

  if (allStations.length === 0) {
    console.error("[fetch-data] No stations fetched. Exiting.");
    await syncPriceStore(new Map(), runRecords, runAt);
    process.exit(1);
  }

  // 按州分组
  const grouped = new Map<AustralianState, Station[]>();
  for (const s of allStations) {
    const group = grouped.get(s.state) ?? [];
    group.push(s);
    grouped.set(s.state, group);
  }

  // 先读已有 metadata —— 用于护栏比较 + 合并
  const existingRaw = await kvGet(KV_KEYS.metadata);
  const existingMeta: Record<string, StateMetadata> = existingRaw
    ? JSON.parse(existingRaw)
    : {};

  // 写入按州 chunk，带最小数量护栏
  const metadataUpdates: Record<string, StateMetadata> = {};
  const writtenStations: Station[] = [];
  // 实际写入的州 → 站点，用于价格历史 roll-up（仅记录通过护栏的健康数据）
  const writtenByState = new Map<AustralianState, Station[]>();
  for (const [state, stations] of grouped) {
    const prev = existingMeta[state]?.station_count ?? 0;
    if (
      prev > RETENTION_GUARD_FLOOR &&
      stations.length < prev * MIN_RETENTION_RATIO
    ) {
      console.warn(
        `[fetch-data] ${state}: ${stations.length} stations vs previous ${prev} ` +
          `(< ${MIN_RETENTION_RATIO * 100}% retention) — skipping overwrite, preserving prior KV`,
      );
      runRecords.push({
        state,
        status: "guarded",
        stationCount: stations.length,
        rowsWritten: 0,
        detail: `previous ${prev}`,
      });
      continue;
    }
    console.log(`[fetch-data] Writing ${state}: ${stations.length} stations...`);
    await kvPut(KV_KEYS.stationsByState(state), JSON.stringify(stations));
    metadataUpdates[state] = {
      last_updated: new Date().toISOString(),
      station_count: stations.length,
    };
    writtenStations.push(...stations);
    writtenByState.set(state, stations);
  }

  if (writtenStations.length === 0) {
    console.error(
      "[fetch-data] Every state failed the retention guard; nothing written.",
    );
    await syncPriceStore(new Map(), runRecords, runAt);
    process.exit(1);
  }

  // 品牌列表 —— 取自全部抓取结果：品牌是 UI 过滤项，超集无害
  const brands = [...new Set(allStations.map((s) => s.brand))].sort();
  await kvPut(KV_KEYS.brands, JSON.stringify(brands));

  // Metadata（合并已有数据，未更新/被护栏跳过的州保留上次记录）
  const merged = { ...existingMeta, ...metadataUpdates };
  await kvPut(KV_KEYS.metadata, JSON.stringify(merged));

  // GET /stations/:id 改为从 stations:{state} chunk 派生（见 kv/read.ts），
  // 不再写单独的 station:{id} key —— 每轮 KV 写入从 ~每站一次降到每州一次。

  // 价格历史每日 roll-up（成功 ingest 后追加，幂等、每州每天一条）
  await capturePriceHistory(writtenByState);

  // D1 价格历史（决策 0006）：KV 仍是读路径，D1 失败只告警
  await syncPriceStore(writtenByState, runRecords, runAt);

  console.log(
    `[fetch-data] Done: ${writtenStations.length} stations written, ${brands.length} brands`,
  );
}

/**
 * 为本次实际写入的每个州追加当日价格快照。
 *
 * 廉价且幂等：读取既有 history:{state}，移除当天旧条目后写入最新快照，
 * 同一天多次运行只保留最后一次。单州失败不影响其他州，也不影响主流程。
 * 日期由 Node 运行时时钟（标准 JS Date API）戳记 —— 这是应用脚本，可用。
 */
async function capturePriceHistory(
  writtenByState: Map<AustralianState, Station[]>,
): Promise<void> {
  const date = utcDate(new Date());
  for (const [state, stations] of writtenByState) {
    try {
      const today = computeDailySnapshots(stations, date);
      if (today.length === 0) continue;

      const existingRaw = await kvGet(KV_KEYS.priceHistory(state));
      const existing: PriceSnapshot[] = existingRaw ? JSON.parse(existingRaw) : [];
      const merged = mergeDailySnapshots(existing, today, date);

      await kvPut(KV_KEYS.priceHistory(state), JSON.stringify(merged));
      console.log(
        `[fetch-data] ${state}: captured ${today.length} fuel snapshots for ${date} ` +
          `(${merged.length} total entries)`,
      );
    } catch (err) {
      // 历史是次要副作用 —— 失败仅告警，不让主流程退出
      console.error(`[fetch-data] ${state}: price history capture failed —`, err);
    }
  }
}

/**
 * 把本轮写入 KV 的各州数据同步进 servo-map-prices D1，并记录每州的 ingest 结果。
 *
 * D1 是历史存储，不在读路径上：未配置时跳过，单州失败只告警、不让 ingest 失败。
 */
async function syncPriceStore(
  writtenByState: Map<AustralianState, Station[]>,
  runRecords: IngestRunRecord[],
  runAt: Date,
): Promise<void> {
  const databaseId = process.env.D1_PRICES_DATABASE_ID;
  if (!databaseId) {
    console.log("[fetch-data] D1_PRICES_DATABASE_ID not set — skipping D1 price history");
    return;
  }
  const exec = d1Executor(databaseId);
  const date = utcDate(runAt);

  for (const [state, stations] of writtenByState) {
    try {
      const snapshots = computeDailySnapshots(stations, date);
      const rowsWritten = await syncStatePrices(exec, stations, snapshots, state, runAt);
      console.log(`[fetch-data] ${state}: D1 wrote ${rowsWritten} rows`);
      runRecords.push({ state, status: "written", stationCount: stations.length, rowsWritten });
    } catch (err) {
      console.error(`[fetch-data] ${state}: D1 price sync failed —`, err);
      runRecords.push({
        state,
        status: "written",
        stationCount: stations.length,
        rowsWritten: 0,
        detail: `KV written; D1 sync failed: ${String(err).slice(0, 400)}`,
      });
    }
  }

  try {
    await recordIngestRuns(exec, runAt, runRecords);
  } catch (err) {
    console.error("[fetch-data] D1 ingest_runs write failed —", err);
  }
}

main().catch((err) => {
  console.error("[fetch-data] Fatal:", err);
  process.exit(1);
});
