import { describe, expect, it } from "vitest";
import { decryptNote, encryptNote, generateNoteKey, type NoteContext } from "../packages/crypto/src/notes";
import { decodeBase64Url, encodeBase64Url, validateEnvelope } from "../packages/protocol/src/note-envelope";

const context: NoteContext = { ownerId: "alice", noteId: "10000000-0000-4000-8000-000000000001",
  keyId: "30000000-0000-4000-8000-000000000003", revision: 1 };
const text = new TextEncoder().encode(JSON.stringify({ title: "\u06cc\u0627\u062f\u062f\u0627\u0634\u062a", content: "\u0633\u0644\u0627\u0645", strokes: [{ points: [[0, 1], [2, 3]] }] }));

describe("client-side authenticated note encryption", () => {
  it("generates a nonexportable AES-256-GCM reference key", async () => {
    const key = await generateNoteKey();
    expect(key.algorithm).toEqual({ name: "AES-GCM", length: 256 });
    expect(key.extractable).toBe(false);
    await expect(crypto.subtle.exportKey("raw", key)).rejects.toThrow();
  });

  it("round-trips title, Persian text and finger-stroke data without plaintext fields", async () => {
    const key = await generateNoteKey();
    const envelope = await encryptNote(key, context, text);
    expect(validateEnvelope(envelope)).toEqual(envelope);
    expect(await decryptNote(key, context, envelope)).toEqual(text);
    expect(Object.keys(envelope).sort()).toEqual(["algorithm", "ciphertext", "format", "keyId", "nonce", "revision"]);
    expect(JSON.stringify(envelope)).not.toContain("strokes");
  });

  it("uses fresh random nonces even for concurrent writes of the same revision", async () => {
    const key = await generateNoteKey();
    const outputs = await Promise.all(Array.from({ length: 20 }, () => encryptNote(key, context, text)));
    expect(new Set(outputs.map((value) => value.nonce)).size).toBe(20);
    expect(new Set(outputs.map((value) => value.ciphertext)).size).toBe(20);
  });

  it("rejects the wrong key", async () => {
    const envelope = await encryptNote(await generateNoteKey(), context, text);
    await expect(decryptNote(await generateNoteKey(), context, envelope)).rejects.toThrow("Unable to authenticate");
  });

  it.each(["nonce", "ciphertext"] as const)("rejects tampered %s", async (field) => {
    const key = await generateNoteKey();
    const envelope = await encryptNote(key, context, text);
    const bytes = decodeBase64Url(envelope[field], 1, 65536);
    bytes[0] = bytes[0]! ^ 1;
    await expect(decryptNote(key, context, { ...envelope, [field]: encodeBase64Url(bytes) })).rejects.toThrow("Unable to authenticate");
  });

  it("rejects a changed authentication tag without returning plaintext", async () => {
    const key = await generateNoteKey();
    const envelope = await encryptNote(key, context, text);
    const bytes = decodeBase64Url(envelope.ciphertext, 16, 65536);
    bytes[bytes.length - 1] = bytes[bytes.length - 1]! ^ 1;
    await expect(decryptNote(key, context, { ...envelope, ciphertext: encodeBase64Url(bytes) })).rejects.toThrow("Unable to authenticate");
  });

  it.each([
    { ownerId: "bob" }, { noteId: "20000000-0000-4000-8000-000000000002" },
    { keyId: "40000000-0000-4000-8000-000000000004" }, { revision: 2 },
  ])("binds ciphertext to its expected owner/document/key/revision %#", async (change) => {
    const key = await generateNoteKey();
    const envelope = await encryptNote(key, context, text);
    // Alter envelope too, so the revision/key checks alone cannot mask a missing AAD binding.
    const modified = { ...envelope,
      ...(change.keyId ? { keyId: change.keyId } : {}), ...(change.revision ? { revision: change.revision } : {}),
    };
    await expect(decryptNote(key, { ...context, ...change }, modified)).rejects.toThrow("Unable to authenticate");
  });

  it("rejects unauthenticated JSON and algorithm downgrade envelopes", async () => {
    const key = await generateNoteKey();
    const envelope = await encryptNote(key, context, text);
    await expect(decryptNote(key, context, { title: "plain", content: "plain" })).rejects.toThrow("Unable to authenticate");
    await expect(decryptNote(key, context, { ...envelope, algorithm: "none" })).rejects.toThrow("Unable to authenticate");
  });

  it("handles empty and maximum-size plaintext and rejects oversized content", async () => {
    const key = await generateNoteKey();
    for (const length of [0, 65520]) {
      const plaintext = new Uint8Array(length).fill(42);
      const envelope = await encryptNote(key, context, plaintext);
      expect(await decryptNote(key, context, envelope)).toEqual(plaintext);
    }
    await expect(encryptNote(key, context, new Uint8Array(65521))).rejects.toThrow("65520");
  });

  it.each([{ ownerId: "" }, { noteId: "not-a-uuid" }, { keyId: "bad" }, { revision: 0 }, { revision: 1.5 }])("rejects invalid client context %#", async (change) => {
    await expect(encryptNote(await generateNoteKey(), { ...context, ...change }, text)).rejects.toThrow("context");
  });

  it("does not accept an AES-128 key", async () => {
    const key = await crypto.subtle.importKey("raw", new Uint8Array(16), "AES-GCM", false, ["encrypt", "decrypt"]);
    await expect(encryptNote(key, context, text)).rejects.toThrow("256-bit");
  });

  it("snapshots metadata before asynchronous encryption", async () => {
    const key = await generateNoteKey();
    const mutable = { ...context };
    const result = encryptNote(key, mutable, text);
    mutable.revision = 2;
    const envelope = await result;
    expect(envelope.revision).toBe(1);
    expect(await decryptNote(key, context, envelope)).toEqual(text);
  });

  it("decrypts the Node/OpenSSL fixed interoperability fixture", async () => {
    // Public test key 00..1f and nonce 00..0b are never used for actual content.
    const key = await crypto.subtle.importKey("raw", Uint8Array.from({ length: 32 }, (_, index) => index), "AES-GCM", false, ["decrypt"]);
    const envelope = { format: 1, algorithm: "A256GCM", keyId: context.keyId, revision: 1,
      nonce: "AAECAwQFBgcICQoL", ciphertext: "BUGZVoigjF-tKPn_1JsXHaOw7kyEDi0ZABv4gFUeoJLNmWaBKUWpwQ" };
    expect(new TextDecoder().decode(await decryptNote(key, context, envelope))).toBe("BCOMMEND interop fixture");
  });
});
