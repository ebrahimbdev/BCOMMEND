import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../crypto/note_cipher.dart';
import '../model/note.dart';

abstract interface class NoteRepository {
  Future<List<Note>> load();
  Future<Note> save(Note note);
  Future<void> delete(String id);
}

abstract interface class VaultKeyStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SaveUncertain implements Exception {
  SaveUncertain(this.note);
  final Note note;
}

class DeleteUncertain implements Exception {}

Future<void> _syncAndroidDirectory(Directory directory) => const MethodChannel(
  'dev.bcommend/storage',
).invokeMethod<void>('syncDirectory', {'path': directory.path});

class DeviceKeyStorage implements VaultKeyStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
  );
  static const _name = 'bcommend.local-vault.v1';
  @override
  Future<String?> read() => _storage.read(key: _name);
  @override
  Future<void> write(String value) => _storage.write(key: _name, value: value);
}

class EncryptedNoteRepository implements NoteRepository {
  EncryptedNoteRepository({
    Future<Directory> Function()? directoryProvider,
    VaultKeyStorage? keyStorage,
    Future<void> Function(Directory)? syncDirectory,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _keyStorage = keyStorage ?? DeviceKeyStorage(),
       _syncDirectory = syncDirectory ?? _syncAndroidDirectory;
  final Future<Directory> Function() _directoryProvider;
  final VaultKeyStorage _keyStorage;
  final Future<void> Function(Directory) _syncDirectory;
  final _cipher = NoteCipher();
  Future<void> _tail = Future.value();
  Directory? _directory;
  SecretKey? _key;
  String? _ownerId, _keyId;

  // One app-wide repository serializes reads/writes and rejects stale revisions.
  Future<T> _run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _open() async {
    if (_key != null) return;
    final root = await _directoryProvider();
    final directory = Directory('${root.path}/encrypted-notes');
    await directory.create(recursive: true);
    var encoded = await _keyStorage.read();
    final marker = File('${directory.path}/vault.meta');
    if (encoded == null) {
      // Never replace a missing key when files exist, even if they are partial/corrupt.
      if (!(await directory.list().isEmpty)) {
        throw StateError('Vault key missing; existing data retained');
      }
      final key = await _cipher.newKey();
      encoded = jsonEncode({
        'format': 1,
        'ownerId': const Uuid().v4(),
        'keyId': const Uuid().v4(),
        'key': NoteCipher.encodeBytes(await key.extractBytes()),
      });
      await _keyStorage.write(encoded);
    }
    final data = jsonDecode(encoded) as Map<String, dynamic>;
    if (data['format'] != 1 ||
        data['ownerId'] is! String ||
        data['keyId'] is! String ||
        !noteUuid.hasMatch(data['ownerId'] as String) ||
        !noteUuid.hasMatch(data['keyId'] as String)) {
      throw const FormatException('Invalid stored vault key');
    }
    final key = SecretKey(NoteCipher.decodeBytes(data['key'], 32, 32));
    final metadata = jsonEncode({
      'format': 1,
      'ownerId': data['ownerId'],
      'keyId': data['keyId'],
    });
    if (await marker.exists()) {
      if (await marker.length() > 1024 ||
          await marker.readAsString() != metadata) {
        throw StateError('Vault identity mismatch; existing data retained');
      }
    } else {
      final entries = await directory.list().toList();
      // Complete an interrupted first marker write using the existing key, never a new key.
      if (entries.any(
        (entry) => entry is! File || entry.path != '${marker.path}.pending',
      )) {
        throw StateError('Vault metadata missing; existing data retained');
      }
      await _atomicWrite(marker, metadata);
    }
    await _syncDirectory(directory);
    await _syncDirectory(root);
    _directory = directory;
    _ownerId = data['ownerId'] as String;
    _keyId = data['keyId'] as String;
    _key = key;
  }

  File _file(String id) {
    if (!noteUuid.hasMatch(id)) {
      throw const FormatException('Invalid note identifier');
    }
    return File('${_directory!.path}/$id.note');
  }

  Future<Note> _read(File file, String id) async {
    if (await file.length() > 100000) {
      throw const FormatException('Note file size limit');
    }
    final envelope =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final revision = envelope['revision'];
    if (revision is! int) throw const FormatException('Invalid note revision');
    final plain = await _cipher.decrypt(
      key: _key!,
      ownerId: _ownerId!,
      noteId: id,
      keyId: _keyId!,
      revision: revision,
      envelope: envelope,
    );
    final note = Note.fromJson(
      jsonDecode(utf8.decode(plain)) as Map<String, dynamic>,
    );
    if (note.id != id || note.revision != revision) {
      throw const FormatException('Note context mismatch');
    }
    return note;
  }

  Future<void> _atomicWrite(File target, String encrypted) async {
    final temporary = File('${target.path}.pending');
    await temporary.writeAsString(encrypted, flush: true);
    // Both paths share app-private storage; Android rename atomically replaces the file.
    await temporary.rename(target.path);
  }

  @override
  Future<List<Note>> load() => _run(() async {
    await _open();
    final notes = <Note>[];
    await for (final file in _directory!.list()) {
      if (file is File && file.path.endsWith('.note')) {
        final name = file.uri.pathSegments.last;
        final id = name.substring(0, name.length - 5);
        if (!noteUuid.hasMatch(id)) {
          throw const FormatException('Invalid note filename');
        }
        notes.add(await _read(file, id));
      }
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  });

  @override
  Future<Note> save(Note note) => _run(() async {
    note.validate();
    await _open();
    final file = _file(note.id);
    final current = await file.exists() ? await _read(file, note.id) : null;
    if ((current?.revision ?? 0) != note.revision) {
      throw StateError('Stale note revision');
    }
    final saved = note.copyWith(
      revision: note.revision + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    final envelope = await _cipher.encrypt(
      key: _key!,
      ownerId: _ownerId!,
      noteId: note.id,
      keyId: _keyId!,
      revision: saved.revision,
      plaintext: utf8.encode(jsonEncode(saved.toJson())),
    );
    await _atomicWrite(file, jsonEncode(envelope));
    try {
      await _syncDirectory(_directory!);
    } catch (_) {
      // Rename succeeded but durability is uncertain. Keep the current revision for a safe retry.
      throw SaveUncertain(saved);
    }
    return saved;
  });

  @override
  Future<void> delete(String id) => _run(() async {
    await _open();
    final file = _file(id);
    final pending = File('${file.path}.pending');
    if (await pending.exists()) await pending.delete();
    if (await file.exists()) await file.delete();
    try {
      await _syncDirectory(_directory!);
    } catch (_) {
      throw DeleteUncertain();
    }
  });
}
