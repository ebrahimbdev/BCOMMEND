import { decodeBase64Url, encodeBase64Url, MAX_CIPHERTEXT_BYTES, UUID, validateEnvelope, type NoteEnvelope } from "../../protocol/src/note-envelope";

export interface NoteContext {
  ownerId: string;
  noteId: string;
  keyId: string;
  revision: number;
}

function additionalData(context: NoteContext): Uint8Array {
  if (!context || typeof context.ownerId !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(context.ownerId)
    || typeof context.noteId !== "string" || !UUID.test(context.noteId)
    || typeof context.keyId !== "string" || !UUID.test(context.keyId)
    || !Number.isSafeInteger(context.revision) || context.revision < 1) {
    throw new Error("Invalid note encryption context");
  }
  return new TextEncoder().encode(JSON.stringify([
    "bcommend.note", 1, context.ownerId, context.noteId, context.keyId, context.revision,
  ]));
}

function checkKey(key: CryptoKey): void {
  if (!key || key.type !== "secret" || key.algorithm.name !== "AES-GCM" || (key.algorithm as { length?: number }).length !== 256) {
    throw new Error("A 256-bit AES-GCM key is required");
  }
}

/** Ephemeral reference key only. Do not store real data until a reviewed client vault can retain/recover it. */
export async function generateNoteKey(): Promise<CryptoKey> {
  const key = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
  if (!("type" in key)) throw new Error("Expected a symmetric key");
  return key;
}

export async function encryptNote(key: CryptoKey, context: NoteContext, plaintext: Uint8Array): Promise<NoteEnvelope> {
  checkKey(key);
  const aad = additionalData(context);
  const { keyId, revision } = context;
  if (!(plaintext instanceof Uint8Array) || plaintext.byteLength > MAX_CIPHERTEXT_BYTES - 16) {
    throw new Error("Note plaintext must be bytes no larger than 65520 bytes");
  }
  // Never derive a nonce from the revision: concurrent offline writers can share a revision.
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce, additionalData: aad, tagLength: 128 }, key, plaintext);
  return { format: 1, algorithm: "A256GCM", keyId, revision,
    nonce: encodeBase64Url(nonce), ciphertext: encodeBase64Url(new Uint8Array(ciphertext)) };
}

export async function decryptNote(key: CryptoKey, context: NoteContext, input: unknown): Promise<Uint8Array> {
  try {
    checkKey(key);
    const aad = additionalData(context);
    const envelope = validateEnvelope(input);
    if (envelope.keyId !== context.keyId || envelope.revision !== context.revision) throw new Error("Context mismatch");
    const plaintext = await crypto.subtle.decrypt({
      name: "AES-GCM", iv: decodeBase64Url(envelope.nonce, 12, 12), additionalData: aad, tagLength: 128,
    }, key, decodeBase64Url(envelope.ciphertext, 16, MAX_CIPHERTEXT_BYTES));
    return new Uint8Array(plaintext);
  } catch {
    // No unauthenticated plaintext or sensitive details escape on any failure.
    throw new Error("Unable to authenticate encrypted note");
  }
}
