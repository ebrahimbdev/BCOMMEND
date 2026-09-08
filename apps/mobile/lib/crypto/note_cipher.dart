import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../model/note.dart';

// Matches packages/crypto/src/notes.ts. No networking or key storage here.
class NoteCipher {
  final _aes = AesGcm.with256bits();
  Future<SecretKey> newKey() => _aes.newSecretKey();

  List<int> _aad(String ownerId, String noteId, String keyId, int revision) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(ownerId) ||
        !noteUuid.hasMatch(noteId) ||
        !noteUuid.hasMatch(keyId) ||
        revision < 1 ||
        revision > 9007199254740991) {
      throw const FormatException('Invalid encryption context');
    }
    return utf8.encode(
      jsonEncode(['bcommend.note', 1, ownerId, noteId, keyId, revision]),
    );
  }

  Future<Map<String, Object>> encrypt({
    required SecretKey key,
    required String ownerId,
    required String noteId,
    required String keyId,
    required int revision,
    required List<int> plaintext,
  }) async {
    if (plaintext.length > 65520) {
      throw const FormatException('Encrypted note size limit');
    }
    final aad = _aad(ownerId, noteId, keyId, revision);
    if ((await key.extractBytes()).length != 32) {
      throw const FormatException('AES-256 key required');
    }
    final box = await _aes.encrypt(
      plaintext,
      secretKey: key,
      nonce: _aes.newNonce(),
      aad: aad,
    );
    return {
      'format': 1,
      'algorithm': 'A256GCM',
      'keyId': keyId,
      'revision': revision,
      'nonce': encodeBytes(box.nonce),
      'ciphertext': encodeBytes([...box.cipherText, ...box.mac.bytes]),
    };
  }

  Future<Uint8List> decrypt({
    required SecretKey key,
    required String ownerId,
    required String noteId,
    required String keyId,
    required int revision,
    required Map<String, dynamic> envelope,
  }) async {
    try {
      const fields = {
        'format',
        'algorithm',
        'keyId',
        'revision',
        'nonce',
        'ciphertext',
      };
      if (envelope.length != fields.length ||
          envelope.keys.any((key) => !fields.contains(key)) ||
          envelope['format'] != 1 ||
          envelope['algorithm'] != 'A256GCM' ||
          envelope['keyId'] != keyId ||
          envelope['revision'] != revision ||
          (await key.extractBytes()).length != 32) {
        throw const FormatException('Invalid envelope');
      }
      final bytes = decodeBytes(envelope['ciphertext'], 16, 65536);
      final nonce = decodeBytes(envelope['nonce'], 12, 12);
      final box = SecretBox(
        bytes.sublist(0, bytes.length - 16),
        nonce: nonce,
        mac: Mac(bytes.sublist(bytes.length - 16)),
      );
      return Uint8List.fromList(
        await _aes.decrypt(
          box,
          secretKey: key,
          aad: _aad(ownerId, noteId, keyId, revision),
        ),
      );
    } catch (_) {
      throw const FormatException('Unable to authenticate encrypted note');
    }
  }

  static String encodeBytes(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');
  static Uint8List decodeBytes(dynamic value, int minimum, int maximum) {
    if (value is! String ||
        value.length > (maximum * 4 / 3).ceil() ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw const FormatException('Invalid encoding');
    }
    final bytes = base64Url.decode(base64Url.normalize(value));
    if (bytes.length < minimum ||
        bytes.length > maximum ||
        encodeBytes(bytes) != value) {
      throw const FormatException('Invalid encoding');
    }
    return bytes;
  }
}
