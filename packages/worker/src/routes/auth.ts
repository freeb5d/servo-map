import { Hono } from "hono";
import type { ApiResponse, SessionResponse } from "@servo-map/shared";
import type { Env } from "../env";
import { JwtError, signSession, verifyIdToken, type IdTokenCheck } from "../auth/jwt";
import { providerCheck, type Provider } from "../auth/providers";
import { upsertAccount } from "../db/accounts";

const PROVIDERS: readonly Provider[] = ["apple", "google"];

/**
 * Sign-in: the app sends the identity token Apple or Google gave it, the Worker checks it against
 * the provider's keys and returns a ServoMap session token. `check` is injectable for tests.
 */
export function createAuthRoute(check: (provider: Provider, env: Env) => IdTokenCheck = providerCheck) {
  const route = new Hono<{ Bindings: Env }>();

  // POST /api/v1/auth/:provider  { identityToken, name? }
  route.post("/:provider", async (c) => {
    const { DB, SESSION_SECRET } = c.env;
    if (!DB || !SESSION_SECRET) {
      return c.json({ status: "error", message: "Accounts are not available yet", code: "ACCOUNTS_UNAVAILABLE" }, 503);
    }
    const provider = c.req.param("provider") as Provider;
    if (!PROVIDERS.includes(provider)) {
      return c.json({ status: "error", message: "Unknown sign-in provider", code: "INVALID_PROVIDER" }, 404);
    }
    const body = await c.req.json<{ identityToken?: unknown; name?: unknown }>().catch(() => ({}) as Record<string, unknown>);
    const identityToken = typeof body.identityToken === "string" ? body.identityToken : "";
    const name = typeof body.name === "string" ? body.name.trim().slice(0, 80) || undefined : undefined;
    if (!identityToken || identityToken.length > 4096) {
      return c.json({ status: "error", message: "identityToken is required", code: "INVALID_TOKEN" }, 400);
    }
    let claims;
    try {
      claims = await verifyIdToken(identityToken, check(provider, c.env));
    } catch (e) {
      // Never echo why a token failed beyond this: it would help someone forge one.
      if (e instanceof JwtError) return c.json({ status: "error", message: "Sign-in could not be verified", code: "UNAUTHENTICATED" }, 401);
      throw e;
    }
    const account = await upsertAccount(DB, {
      provider,
      subject: claims.sub!,
      email: typeof claims.email === "string" ? claims.email : undefined,
      // Google's own name is used when the app did not send one (Apple sends it once, from the app).
      name: name ?? (typeof claims.name === "string" ? claims.name.slice(0, 80) : undefined),
      picture: typeof claims.picture === "string" && claims.picture.startsWith("https://") ? claims.picture : undefined,
    });
    const token = await signSession(account.id, SESSION_SECRET);
    return c.json({ status: "success", data: { token, account } } satisfies ApiResponse<SessionResponse>);
  });

  return route;
}

export const authRoute = createAuthRoute();
