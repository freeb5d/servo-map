/**
 * Cloudflare D1 over the REST API, for scripts that run outside the Worker (GitHub Actions).
 * The one D1 client for scripts: the ingest (price history) and the alert job (accounts) use it.
 *
 * Env: CF_ACCOUNT_ID, CF_API_TOKEN (the token needs D1 Read and D1 Write).
 */

import type { SqlExecutor } from "../packages/worker/src/prices-db/sync";

interface D1QueryResponse<T> {
  success: boolean;
  errors?: { message: string }[];
  result?: { results?: T[]; meta?: { rows_written?: number } }[];
}

export interface D1QueryResult<T> {
  results: T[];
  rowsWritten: number;
}

/** Runs one statement against a database; retries on rate limiting like the KV writer. */
export async function d1Query<T = Record<string, unknown>>(
  databaseId: string,
  sql: string,
  params: unknown[] = [],
  retries = 3,
): Promise<D1QueryResult<T>> {
  const accountId = process.env.CF_ACCOUNT_ID;
  const token = process.env.CF_API_TOKEN;
  if (!accountId || !token) throw new Error("Missing env: CF_ACCOUNT_ID or CF_API_TOKEN");
  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/d1/database/${databaseId}/query`;

  for (let attempt = 0; ; attempt++) {
    const res = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ sql, params }),
    });
    if (res.status === 429 && attempt < retries) {
      await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
      continue;
    }
    const body = (await res.json().catch(() => null)) as D1QueryResponse<T> | null;
    if (!res.ok || !body?.success) {
      const reason = body?.errors?.map((e) => e.message).join("; ") ?? res.statusText;
      throw new Error(`D1 query failed: ${res.status} — ${reason}`);
    }
    const result = body.result ?? [];
    return {
      results: result[0]?.results ?? [],
      rowsWritten: result.reduce((n, r) => n + (r.meta?.rows_written ?? 0), 0),
    };
  }
}

/** An executor bound to one database, in the shape the price-history sync expects. */
export function d1Executor(databaseId: string): SqlExecutor {
  return async (sql, params) => ({ rowsWritten: (await d1Query(databaseId, sql, params)).rowsWritten });
}
