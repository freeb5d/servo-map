/** Test helpers: an RSA key pair and identity tokens signed the way Apple and Google sign theirs. */
export async function rsaKeyPair(): Promise<CryptoKeyPair> {
  return (await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"],
  )) as CryptoKeyPair;
}

const enc = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");

export async function signIdToken(payload: object, kid: string, key: CryptoKey): Promise<string> {
  const head = enc({ alg: "RS256", kid });
  const body = enc(payload);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${body}`));
  return `${head}.${body}.${Buffer.from(sig).toString("base64url")}`;
}
