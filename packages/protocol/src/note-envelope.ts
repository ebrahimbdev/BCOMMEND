export interface NoteEnvelope {
  format: 1;
  algorithm: "A256GCM";
  keyId: string;
  revision: number;
  nonce: string;
  ciphertext: string;
}

export const MAX_CIPHERTEXT_BYTES = 65536;
export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

export function encodeBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 8192) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 8192));
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function decodeBase64Url(value: unknown, minBytes: number, maxBytes: number): Uint8Array {
  if (typeof value !== "string" || value.length > Math.ceil(maxBytes * 4 / 3) || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new Error("Invalid base64url encoding");
  }
  const binary = atob(value.replace(/-/g, "+").replace(/_/g, "/"));
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  if (bytes.length < minBytes || bytes.length > maxBytes || encodeBase64Url(bytes) !== value) {
    throw new Error("Noncanonical or out-of-range base64url value");
  }
  return bytes;
}

/** Shape validation is not authentication: only a client holding the key can verify the GCM tag. */
export function validateEnvelope(value: unknown): NoteEnvelope {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid encrypted envelope");
  const data = value as Record<string, unknown>;
  const fields = ["format", "algorithm", "keyId", "revision", "nonce", "ciphertext"];
  if (Object.keys(data).length !== fields.length || Object.keys(data).some((field) => !fields.includes(field))) {
    throw new Error("Unexpected encrypted envelope field");
  }
  if (data.format !== 1 || data.algorithm !== "A256GCM" || typeof data.keyId !== "string" || !UUID.test(data.keyId)) {
    throw new Error("Unsupported encrypted envelope format or key identifier");
  }
  if (!Number.isSafeInteger(data.revision) || (data.revision as number) < 1) throw new Error("Invalid encrypted revision");
  decodeBase64Url(data.nonce, 12, 12);
  decodeBase64Url(data.ciphertext, 16, MAX_CIPHERTEXT_BYTES);
  return { format: 1, algorithm: "A256GCM", keyId: data.keyId, revision: data.revision as number,
    nonce: data.nonce as string, ciphertext: data.ciphertext as string };
}
