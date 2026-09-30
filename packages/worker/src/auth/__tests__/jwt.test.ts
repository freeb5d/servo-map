import { describe, it, expect, beforeAll } from "vitest";
import { JwtError, signSession, verifyIdToken, verifySession } from "../jwt";
import { rsaKeyPair, signIdToken as sign } from "../__mocks__/id-token";

const enc = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");
let keys: CryptoKeyPair;
let publicJwk: JsonWebKey;

const signIdToken = (payload: object, kid = "test-key", key?: CryptoKey) => sign(payload, kid, key ?? keys.privateKey);

beforeAll(async () => {
  keys = await rsaKeyPair();
  publicJwk = (await crypto.subtle.exportKey("jwk", keys.publicKey)) as JsonWebKey;
});

const now = 1_800_000_000;
const check = () => ({ issuers: ["https://appleid.apple.com"], audiences: ["com.misoto22.servomap"], key: async (kid: string) => (kid === "test-key" ? publicJwk : undefined), now });
const good = { iss: "https://appleid.apple.com", aud: "com.misoto22.servomap", sub: "001234.abc", exp: now + 600, email: "a@b.com" };

describe("verifyIdToken", () => {
  it("accepts a well-signed token for our audience", async () => {
    const claims = await verifyIdToken(await signIdToken(good), check());
    expect(claims.sub).toBe("001234.abc");
    expect(claims.email).toBe("a@b.com");
  });

  it.each([
    ["wrong audience", { ...good, aud: "com.someone.else" }],
    ["wrong issuer", { ...good, iss: "https://evil.example" }],
    ["expired", { ...good, exp: now - 120 }],
    ["no subject", { ...good, sub: undefined }],
  ])("rejects a token with %s", async (_n, payload) => {
    await expect(verifyIdToken(await signIdToken(payload), check())).rejects.toBeInstanceOf(JwtError);
  });

  it("rejects an unknown key and a forged signature", async () => {
    await expect(verifyIdToken(await signIdToken(good, "other"), check())).rejects.toThrow(/Unknown signing key/);
    const other = await rsaKeyPair();
    await expect(verifyIdToken(await signIdToken(good, "test-key", other.privateKey), check())).rejects.toThrow(/Bad signature/);
  });

  it("rejects garbage", async () => {
    await expect(verifyIdToken("not.a.token", check())).rejects.toBeInstanceOf(JwtError);
    await expect(verifyIdToken("nope", check())).rejects.toBeInstanceOf(JwtError);
  });
});

describe("session tokens", () => {
  it("round-trips a user id", async () => {
    const t = await signSession("user-1", "secret", now);
    expect(await verifySession(t, "secret", now + 10)).toBe("user-1");
  });

  it("rejects another secret, expiry and tampering", async () => {
    const t = await signSession("user-1", "secret", now);
    await expect(verifySession(t, "other", now)).rejects.toThrow(/Bad signature/);
    await expect(verifySession(t, "secret", now + 200 * 24 * 3600)).rejects.toThrow(/expired/);
    const [h, , s] = t.split(".");
    const forged = `${h}.${enc({ iss: "servo-map", sub: "user-2", exp: now + 999 })}.${s}`;
    await expect(verifySession(forged, "secret", now)).rejects.toThrow(/Bad signature/);
  });
});
