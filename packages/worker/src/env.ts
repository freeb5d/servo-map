export interface Env {
  KV: KVNamespace;

  // Secrets — set via `wrangler secret put` or `.dev.vars`
  NSW_API_KEY: string;
  NSW_API_AUTH: string; // Basic auth header for OAuth token request
  QLD_API_TOKEN: string;

  // Accounts (decision 0004). DB is the D1 database; SESSION_SECRET signs session tokens. Optional
  // so the read API deploys and runs before accounts are provisioned; account routes answer 503.
  DB?: D1Database;
  SESSION_SECRET?: string;
  // Comma-separated audiences accepted in identity tokens: the iOS bundle id (and web Services ID)
  // for Apple, OAuth client ids for Google. Plain vars, not secrets.
  APPLE_AUDIENCES?: string;
  GOOGLE_CLIENT_IDS?: string;

  // Price history (decision 0006). Written by the ingest script; optional until a route reads it.
  PRICES?: D1Database;

  // Fine-grained GitHub PAT (Actions: read+write) used by the scheduled handler
  // to dispatch the ingest workflow. Optional — only the cron path needs it.
  GH_DISPATCH_TOKEN?: string;
}
