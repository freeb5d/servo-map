/**
 * Cloudflare D1 over the REST API, for scripts that run outside the Worker (GitHub Actions).
 *
 * Env: CF_ACCOUNT_ID, CF_API_TOKEN (the token needs D1 Write).
 */

import type { SqlExecutor } from "../packages/worker/src/prices-db/sync";

interface D1QueryResponse {
  success: boolean;
  errors?: { message: string }[];
  result?: { meta?: { rows_written?: number } }[];
}

/** Returns an executor bound to one database; retries on rate limiting like the KV writer. */
export function d1Executor(databaseId: string, retries = 3): SqlExecutor {
  const accountId = process.env.CF_ACCOUNT_ID;
  const token = process.env.CF_API_TOKEN;
  if (!accountId || !token) throw new Error("Missing env: CF_ACCOUNT_ID or CF_API_TOKEN");
  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/d1/database/${databaseId}/query`;

  return async (sql, params) => {
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
      const body = (await res.json().catch(() => null)) as D1QueryResponse | null;
      if (!res.ok || !body?.success) {
        const reason = body?.errors?.map((e) => e.message).join("; ") ?? res.statusText;
        throw new Error(`D1 query failed: ${res.status} — ${reason}`);
      }
      const rowsWritten = (body.result ?? []).reduce((n, r) => n + (r.meta?.rows_written ?? 0), 0);
      return { rowsWritten };
    }
  };
}
