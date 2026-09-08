import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bcommend_mobile/crypto/note_cipher.dart';

void main() {
  const id = '10000000-0000-4000-8000-000000000001';
  const keyId = '30000000-0000-4000-8000-000000000003';
  final cipher = NoteCipher();
  final payload = utf8.encode(
    '{"title":"یادداشت خصوصی","body":"سلام","strokes":[[1,2]]}',
  );
  Future<Map<String, Object>> encrypt(SecretKey key) => cipher.encrypt(
    key: key,
    ownerId: 'alice',
    noteId: id,
    keyId: keyId,
    revision: 1,
    plaintext: payload,
  );
  Future<List<int>> decrypt(
    SecretKey key,
    Map<String, dynamic> envelope, {
    String owner = 'alice',
    String note = id,
    String kid = keyId,
    int revision = 1,
  }) => cipher.decrypt(
    key: key,
    ownerId: owner,
    noteId: note,
    keyId: kid,
    revision: revision,
    envelope: envelope,
  );

  test(
    'Dart decrypts the existing Node/OpenSSL interoperability fixture',
    () async {
      final key = SecretKey(List.generate(32, (i) => i));
      final envelope = {
        'format': 1,
        'algorithm': 'A256GCM',
        'keyId': keyId,
        'revision': 1,
        'nonce': 'AAECAwQFBgcICQoL',
        'ciphertext': 'BUGZVoigjF-tKPn_1JsXHaOw7kyEDi0ZABv4gFUeoJLNmWaBKUWpwQ',
      };
      expect(
        utf8.decode(await decrypt(key, envelope)),
        'BCOMMEND interop fixture',
      );
    },
  );

  test('round trip Persian data, empty content, and size boundary', () async {
    final key = await cipher.newKey();
    expect(await decrypt(key, await encrypt(key)), payload);
    for (final size in [0, 65520]) {
      final bytes = List.filled(size, 42);
      final envelope = await cipher.encrypt(
        key: key,
        ownerId: 'alice',
        noteId: id,
        keyId: keyId,
        revision: 1,
        plaintext: bytes,
      );
      expect(await decrypt(key, envelope), bytes);
    }
    await expectLater(
      cipher.encrypt(
        key: key,
        ownerId: 'alice',
        noteId: id,
        keyId: keyId,
        revision: 1,
        plaintext: List.filled(65521, 0),
      ),
      throwsFormatException,
    );
  });

  test('fresh nonce for every competing encryption of a revision', () async {
    final key = await cipher.newKey();
    final results = await Future.wait(List.generate(12, (_) => encrypt(key)));
    expect(results.map((e) => e['nonce']).toSet().length, 12);
  });

  test(
    'wrong key and swapped document/owner/revision/key identifier fail',
    () async {
      final key = await cipher.newKey();
      final envelope = await encrypt(key);
      await expectLater(
        decrypt(await cipher.newKey(), envelope),
        throwsFormatException,
      );
      await expectLater(
        decrypt(key, envelope, owner: 'bob'),
        throwsFormatException,
      );
      await expectLater(
        decrypt(key, envelope, note: '20000000-0000-4000-8000-000000000002'),
        throwsFormatException,
      );
      await expectLater(
        decrypt(key, {...envelope, 'revision': 2}, revision: 2),
        throwsFormatException,
      );
      const other = '40000000-0000-4000-8000-000000000004';
      await expectLater(
        decrypt(key, {...envelope, 'keyId': other}, kid: other),
        throwsFormatException,
      );
    },
  );

  test('tampered nonce, ciphertext and tag fail authentication', () async {
    final key = await cipher.newKey();
    final envelope = await encrypt(key);
    for (final field in ['nonce', 'ciphertext']) {
      final bytes = NoteCipher.decodeBytes(envelope[field], 1, 65536);
      for (final index in [0, bytes.length - 1]) {
        bytes[index] ^= 1;
        await expectLater(
          decrypt(key, {...envelope, field: NoteCipher.encodeBytes(bytes)}),
          throwsFormatException,
        );
        bytes[index] ^= 1;
      }
    }
  });

  test(
    'rejects plaintext, extra fields, padding and unsupported algorithms',
    () async {
      final key = await cipher.newKey();
      final envelope = await encrypt(key);
      for (final invalid in [
        <String, dynamic>{'title': 'plain'},
        {...envelope, 'key': 'bad'},
        {...envelope, 'nonce': '${envelope['nonce']}='},
        {...envelope, 'algorithm': 'none'},
        {...envelope, 'ciphertext': 'AAAAAAAAAAAAAAAAAAAAAB'},
      ]) {
        await expectLater(decrypt(key, invalid), throwsFormatException);
      }
    },
  );
}
