/**
 * JSON Web Tokens with WebCrypto only: verifying Apple and Google identity tokens (RS256 against
 * the provider's published keys) and issuing and checking ServoMap's own session tokens (HS256).
 */

type Json = Record<string, unknown>;

export interface JwtPayload extends Json {
  iss?: string;
  sub?: string;
  aud?: string | string[];
  exp?: number;
  iat?: number;
  email?: string;
}

export class JwtError extends Error {}

const encoder = new TextEncoder();

function base64UrlDecode(input: string): Uint8Array {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(input.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function base64UrlEncode(bytes: Uint8Array | string): string {
  const data = typeof bytes === "string" ? encoder.encode(bytes) : bytes;
  let binary = "";
  for (const b of data) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function decodePart<T>(part: string): T {
  try {
    return JSON.parse(new TextDecoder().decode(base64UrlDecode(part))) as T;
  } catch {
    throw new JwtError("Malformed token");
  }
}

function split(token: string): [string, string, string] {
  const parts = token.split(".");
  if (parts.length !== 3) throw new JwtError("Malformed token");
  return parts as [string, string, string];
}

/** Rejects expired tokens, allowing a minute of clock skew. */
function checkTime(payload: JwtPayload, now: number): void {
  if (typeof payload.exp !== "number" || payload.exp + 60 < now) throw new JwtError("Token expired");
}

export interface IdTokenCheck {
  /** Accepted `iss` values. */
  issuers: readonly string[];
  /** Accepted `aud` values: app bundle ids and OAuth client ids. */
  audiences: readonly string[];
  /** Looks up the provider's public key by `kid`. */
  key: (kid: string) => Promise<JsonWebKey | undefined>;
  now?: number;
}

/** Verifies an RS256 identity token from Apple or Google and returns its claims. */
export async function verifyIdToken(token: string, check: IdTokenCheck): Promise<JwtPayload> {
  const [h, p, s] = split(token);
  const header = decodePart<{ alg?: string; kid?: string }>(h);
  if (header.alg !== "RS256" || !header.kid) throw new JwtError("Unsupported token");
  const jwk = await check.key(header.kid);
  if (!jwk) throw new JwtError("Unknown signing key");
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, base64UrlDecode(s), encoder.encode(`${h}.${p}`));
  if (!ok) throw new JwtError("Bad signature");
  const payload = decodePart<JwtPayload>(p);
  checkTime(payload, check.now ?? Math.floor(Date.now() / 1000));
  if (!payload.iss || !check.issuers.includes(payload.iss)) throw new JwtError("Wrong issuer");
  const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!aud.some((a) => a && check.audiences.includes(a))) throw new JwtError("Wrong audience");
  if (!payload.sub) throw new JwtError("No subject");
  return payload;
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}

/** Session lifetime: long, because the app has no sign-out pressure and tokens are revocable by deleting the account. */
export const SESSION_SECONDS = 180 * 24 * 3600;

/** Issues a ServoMap session token for `userId`. */
export async function signSession(userId: string, secret: string, now = Math.floor(Date.now() / 1000)): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = base64UrlEncode(JSON.stringify({ iss: "servo-map", sub: userId, iat: now, exp: now + SESSION_SECONDS }));
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", await hmacKey(secret), encoder.encode(`${header}.${payload}`)));
  return `${header}.${payload}.${base64UrlEncode(sig)}`;
}

/** Checks a ServoMap session token and returns the user id it was issued for. */
export async function verifySession(token: string, secret: string, now = Math.floor(Date.now() / 1000)): Promise<string> {
  const [h, p, s] = split(token);
  const header = decodePart<{ alg?: string }>(h);
  if (header.alg !== "HS256") throw new JwtError("Unsupported token");
  const ok = await crypto.subtle.verify("HMAC", await hmacKey(secret), base64UrlDecode(s), encoder.encode(`${h}.${p}`));
  if (!ok) throw new JwtError("Bad signature");
  const payload = decodePart<JwtPayload>(p);
  checkTime(payload, now);
  if (payload.iss !== "servo-map" || !payload.sub) throw new JwtError("Not a session token");
  return payload.sub;
}
