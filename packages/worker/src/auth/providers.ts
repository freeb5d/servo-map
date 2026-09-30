import type { Env } from "../env";
import type { IdTokenCheck } from "./jwt";

export type Provider = "apple" | "google";

const JWKS: Record<Provider, string> = {
  apple: "https://appleid.apple.com/auth/keys",
  google: "https://www.googleapis.com/oauth2/v3/certs",
};

const ISSUERS: Record<Provider, readonly string[]> = {
  apple: ["https://appleid.apple.com"],
  google: ["https://accounts.google.com", "accounts.google.com"],
};

/** Comma-separated config value to a clean list. */
function list(value: string | undefined): string[] {
  return (value ?? "").split(",").map((s) => s.trim()).filter(Boolean);
}

/**
 * How to check an identity token from `provider`: its issuer, the audiences this app answers to
 * (from config), and its public keys, fetched from the provider and cached at the edge for an hour.
 */
export function providerCheck(provider: Provider, env: Env): IdTokenCheck {
  const audiences = provider === "apple" ? list(env.APPLE_AUDIENCES) : list(env.GOOGLE_CLIENT_IDS);
  return {
    issuers: ISSUERS[provider],
    audiences,
    key: async (kid) => {
      const res = await fetch(JWKS[provider], { cf: { cacheTtl: 3600, cacheEverything: true } } as RequestInit);
      if (!res.ok) return undefined;
      const { keys } = (await res.json()) as { keys: (JsonWebKey & { kid?: string })[] };
      return keys.find((k) => k.kid === kid);
    },
  };
}
