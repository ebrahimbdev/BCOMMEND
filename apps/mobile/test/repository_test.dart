import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bcommend_mobile/model/note.dart';
import 'package:bcommend_mobile/storage/note_repository.dart';

class MemoryKeys implements VaultKeyStorage {
  String? value;
  bool failWrite = false;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('Synthetic secure storage failure');
    this.value = value;
    writes++;
  }
}

void main() {
  late Directory root;
  late MemoryKeys keys;
  late EncryptedNoteRepository repository;
  var failSync = false;
  const id = '10000000-0000-4000-8000-000000000001';
  Note draft() => Note(
    id: id,
    title: 'عنوان خصوصی',
    body: 'متن مخفی',
    updatedAt: DateTime.utc(2026),
    strokes: [
      InkStroke(
        color: 0xff123456,
        width: 4,
        points: [const InkPoint(1, 2), const InkPoint(3, 4)],
      ),
    ],
  );
  EncryptedNoteRepository open() => EncryptedNoteRepository(
    directoryProvider: () async => root,
    keyStorage: keys,
    syncDirectory: (_) async {
      if (failSync) {
        throw const FileSystemException('Synthetic directory sync failure');
      }
    },
  );
  File noteFile() => File('${root.path}/encrypted-notes/$id.note');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bcommend-test-');
    keys = MemoryKeys();
    failSync = false;
    repository = open();
  });
  tearDown(() async => root.delete(recursive: true));

  test('recovers a partial first marker using the existing key only', () async {
    await repository.load();
    final marker = File('${root.path}/encrypted-notes/vault.meta');
    final expected = await marker.readAsString();
    await marker.rename('${marker.path}.pending');
    await File('${marker.path}.pending').writeAsString('{partial');
    expect(await open().load(), isEmpty);
    expect(await marker.readAsString(), expected);
    expect(keys.writes, 1);
  });

  test('missing marker with unknown files still fails closed', () async {
    await repository.load();
    final marker = File('${root.path}/encrypted-notes/vault.meta');
    await marker.rename('${marker.path}.unknown');
    await expectLater(open().load(), throwsStateError);
    expect(await File('${marker.path}.unknown').exists(), isTrue);
    expect(keys.writes, 1);
  });

  test(
    'uncertain durable save exposes committed revision for a safe retry',
    () async {
      await repository.load();
      failSync = true;
      Note? written;
      try {
        await repository.save(draft());
      } on SaveUncertain catch (error) {
        written = error.note;
      }
      expect(written?.revision, 1);
      failSync = false;
      final retried = await repository.save(written!);
      expect(retried.revision, 2);
      expect((await open().load()).single.toJson(), retried.toJson());
    },
  );

  test(
    'uncertain deletion retries directory sync even when file is absent',
    () async {
      await repository.save(draft());
      failSync = true;
      await expectLater(repository.delete(id), throwsA(isA<DeleteUncertain>()));
      expect(await noteFile().exists(), isFalse);
      failSync = false;
      await repository.delete(id);
      expect(await open().load(), isEmpty);
    },
  );

  test(
    'combined fractional ink and Persian text obey aggregate byte budget',
    () async {
      final original = await repository.save(draft());
      final oversized = original.copyWith(
        body: 'ی' * 18000,
        strokes: List.generate(
          4,
          (_) => InkStroke(
            color: 0xff123456,
            width: 5,
            points: List.generate(
              512,
              (index) =>
                  InkPoint(index + 0.1234567890123, index + 0.9876543210123),
            ),
          ),
        ),
      );
      expect(oversized.fitsStorage, isFalse);
      await expectLater(repository.save(oversized), throwsFormatException);
      expect((await repository.load()).single.toJson(), original.toJson());
    },
  );

  test(
    'encrypted text and ink survive reopening with the secure-store key',
    () async {
      expect(await repository.load(), isEmpty);
      final saved = await repository.save(draft());
      expect(saved.revision, 1);
      final loaded = await open().load();
      expect(loaded.single.toJson(), saved.toJson());
      expect(keys.writes, 1);
      final bytes = await noteFile().readAsString();
      expect(bytes, isNot(contains('عنوان خصوصی')));
      expect(bytes, isNot(contains('متن مخفی')));
      expect(bytes, isNot(contains('points')));
      expect(bytes, isNot(contains((jsonDecode(keys.value!) as Map)['key'])));
      expect(await File('${noteFile().path}.pending').exists(), isFalse);
    },
  );

  test(
    'serialized competing saves produce one winner, without overwriting newer data',
    () async {
      final saved = await repository.save(draft());
      final first = repository.save(saved.copyWith(body: 'new'));
      final second = repository.save(saved.copyWith(body: 'stale'));
      await expectLater(second, throwsStateError);
      expect((await first).revision, 2);
      expect((await repository.load()).single.body, 'new');
    },
  );

  test(
    'missing key never recreates key or erases existing encrypted files',
    () async {
      await repository.save(draft());
      final before = await noteFile().readAsString();
      keys.value = null;
      await expectLater(open().load(), throwsStateError);
      expect(keys.writes, 1);
      expect(await noteFile().readAsString(), before);
    },
  );

  test('corrupted envelope fails without replacing or deleting it', () async {
    await repository.save(draft());
    await noteFile().writeAsString('{broken');
    await expectLater(open().load(), throwsFormatException);
    await expectLater(
      repository.save(draft().copyWith(revision: 1)),
      throwsFormatException,
    );
    expect(await noteFile().readAsString(), '{broken');
  });

  test('key identity mismatch fails closed', () async {
    await repository.save(draft());
    final data = jsonDecode(keys.value!) as Map<String, dynamic>;
    data['ownerId'] = '20000000-0000-4000-8000-000000000002';
    keys.value = jsonEncode(data);
    await expectLater(open().load(), throwsStateError);
    expect(await noteFile().exists(), isTrue);
  });

  test('failed keystore provisioning cannot write a note', () async {
    keys.failWrite = true;
    await expectLater(repository.save(draft()), throwsStateError);
    expect(await noteFile().exists(), isFalse);
    keys.failWrite = false;
    expect((await repository.save(draft())).revision, 1);
  });

  test(
    'oversize content and path traversal are rejected before persistence',
    () async {
      await expectLater(
        repository.save(draft().copyWith(body: 'x' * 20001)),
        throwsFormatException,
      );
      await expectLater(
        repository.save(Note(id: '../bad', updatedAt: DateTime.utc(2026))),
        throwsFormatException,
      );
      await expectLater(repository.delete('../bad'), throwsFormatException);
      expect(await repository.load(), isEmpty);
    },
  );

  test(
    'delete removes ciphertext and stale revision cannot resurrect it',
    () async {
      final saved = await repository.save(draft());
      await repository.delete(saved.id);
      expect(await repository.load(), isEmpty);
      await expectLater(repository.save(saved), throwsStateError);
      expect(await noteFile().exists(), isFalse);
    },
  );
}
