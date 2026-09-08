import 'dart:async';

import 'package:bcommend_mobile/main.dart';
import 'package:bcommend_mobile/model/note.dart';
import 'package:bcommend_mobile/storage/note_repository.dart';
import 'package:bcommend_mobile/ui/ink_canvas.dart';
import 'package:bcommend_mobile/ui/notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotes implements NoteRepository {
  final Map<String, Note> notes = {};
  bool failLoad = false;
  bool failSave = false;
  bool failDelete = false;
  bool uncertainSave = false;
  bool uncertainDelete = false;
  int saveCalls = 0;
  int deleteCalls = 0;
  Completer<void>? saveGate;

  @override
  Future<List<Note>> load() async {
    if (failLoad) throw StateError('locked');
    return notes.values.toList();
  }

  @override
  Future<Note> save(Note note) async {
    saveCalls++;
    note.validate();
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('full');
    if ((notes[note.id]?.revision ?? 0) != note.revision) {
      throw StateError('stale');
    }
    final saved = note.copyWith(
      revision: note.revision + 1,
      updatedAt: DateTime.now(),
    );
    notes[note.id] = saved;
    if (uncertainSave) throw SaveUncertain(saved);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls++;
    if (failDelete) throw StateError('locked');
    notes.remove(id);
    if (uncertainDelete) throw DeleteUncertain();
  }
}

Future<void> create(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('create-note')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('create-note')));
  await tester.pumpAndSettle();
}

Note fullNote() {
  final note = Note(
    id: '11111111-1111-4111-8111-111111111111',
    title: List.filled(199, 'a').join(),
    revision: 1,
    updatedAt: DateTime.utc(2026),
    strokes: List.generate(
      2,
      (_) => InkStroke(
        color: 0xff172b29,
        width: 5,
        points: List.generate(
          512,
          (i) => InkPoint(i + 0.1234567890123, i + 0.9876543210987),
        ),
      ),
    ),
  );
  var low = 0;
  var high = 20000;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (note.copyWith(body: List.filled(middle, '\u4e00').join()).fitsStorage) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  var result = note.copyWith(body: List.filled(low, '\u4e00').join());
  while (result.copyWith(body: '${result.body}x').fitsStorage) {
    result = result.copyWith(body: '${result.body}x');
  }
  result.validate();
  return result;
}

Future<void> openExisting(
  WidgetTester tester,
  FakeNotes repository,
  Note note,
) async {
  repository.notes[note.id] = note;
  await tester.pumpWidget(BcommendApp(repository: repository));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(ListTile));
  await tester.tap(find.byType(ListTile));
  await tester.pumpAndSettle();
}

void main() {
  for (final action in ['save', 'back']) {
    testWidgets('held finger blocks $action on clean note until ink commits', (
      tester,
    ) async {
      final repository = FakeNotes();
      final note = Note(
        id: '11111111-1111-4111-8111-111111111111',
        title: 'existing',
        revision: 1,
        updatedAt: DateTime.utc(2026),
      );
      await openExisting(tester, repository, note);
      await tester.tap(find.text('دست‌نوشته'));
      await tester.pumpAndSettle();
      final finger = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('ink-surface'))),
        pointer: 7,
      );
      await finger.moveBy(const Offset(20, 30));
      await tester.pump();
      for (final button in [
        find.byKey(const Key('save-note')),
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'بازگشت',
        ),
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'حذف یادداشت',
        ),
      ]) {
        expect(tester.widget<IconButton>(button).onPressed, isNull);
      }
      final tab = find.widgetWithText(TextButton, 'متن');
      expect(tester.widget<TextButton>(tab).onPressed, isNull);
      await tester.tap(tab);
      if (action == 'save') {
        await tester.tap(find.byKey(const Key('save-note')));
      } else {
        await tester.tap(find.byTooltip('بازگشت'));
        await tester.binding.handlePopRoute();
      }
      await tester.pump();
      expect(find.byType(InkCanvas), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.saveCalls, 0);
      expect(repository.notes[note.id]!.strokes, isEmpty);
      await finger.up();
      await tester.pump();
      expect(tester.widget<TextButton>(tab).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('save-note')));
      await tester.pumpAndSettle();
      expect(repository.notes[note.id]!.strokes, hasLength(1));
      expect(
        repository.notes[note.id]!.strokes.single.points.length,
        greaterThan(1),
      );
      expect(repository.notes[note.id]!.revision, 2);
      await tester.tap(find.byTooltip('بازگشت'));
      await tester.pumpAndSettle();
      expect(find.byType(InkCanvas), findsNothing);
    });
  }

  for (final title in [true, false]) {
    testWidgets(
      'aggregate budget rejects ${title ? 'title' : 'body'} input intact',
      (tester) async {
        final repository = FakeNotes();
        final note = fullNote();
        await openExisting(tester, repository, note);
        final field = find.byKey(Key(title ? 'note-title' : 'note-body'));
        final accepted = title ? note.title : note.body;
        expect(accepted.length + 1, lessThanOrEqualTo(title ? 200 : 20000));
        await tester.enterText(field, '$accepted\u4e00');
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, accepted);
        expect(
          find.textContaining('ظرفیت ذخیره یادداشت پر است'),
          findsOneWidget,
        );
        expect(repository.saveCalls, 0);
        await tester.enterText(
          field,
          accepted.substring(0, accepted.length - 1),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('save-note')));
        await tester.pumpAndSettle();
        final saved = repository.notes[note.id]!;
        expect(
          title ? saved.title : saved.body,
          accepted.substring(0, accepted.length - 1),
        );
        expect(saved.strokes, note.strokes);
        expect(saved.fitsStorage, isTrue);
      },
    );
  }

  testWidgets(
    'aggregate budget rejects actual new ink preserving fractional strokes',
    (tester) async {
      final repository = FakeNotes();
      final note = fullNote();
      await openExisting(tester, repository, note);
      await tester.tap(find.text('دست‌نوشته'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('ink-surface')),
        const Offset(23, 31),
      );
      await tester.pump();
      expect(find.textContaining('ظرفیت ذخیره یادداشت پر است'), findsOneWidget);
      expect(
        tester.widget<InkCanvas>(find.byType(InkCanvas)).strokes,
        note.strokes,
      );
      expect(
        tester.widget<IconButton>(find.byKey(const Key('save-note'))).onPressed,
        isNull,
      );
      expect(repository.saveCalls, 0);
      await tester.tap(find.byKey(const Key('undo-stroke')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-note')));
      await tester.pumpAndSettle();
      expect(repository.notes[note.id]!.strokes, [note.strokes.first]);
    },
  );

  testWidgets('save checks aggregate budget even for controller changes', (
    tester,
  ) async {
    final repository = FakeNotes();
    final note = fullNote();
    await openExisting(tester, repository, note);
    final field = find.byKey(const Key('note-title'));
    await tester.enterText(field, note.title.substring(1));
    await tester.pump();
    tester.widget<TextField>(field).controller!.text = '${note.title}x';
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 0);
    expect(find.textContaining('ظرفیت ذخیره یادداشت پر است'), findsOneWidget);
    expect(find.textContaining('ذخیره نشد.'), findsNothing);
  });

  testWidgets('uncertain save retains draft and retries advanced revision', (
    tester,
  ) async {
    final repository = FakeNotes()..uncertainSave = true;
    await tester.pumpWidget(BcommendApp(repository: repository));
    await tester.pumpAndSettle();
    await create(tester);
    await tester.enterText(find.byKey(const Key('note-title')), 'draft');
    await tester.enterText(find.byKey(const Key('note-body')), 'private body');
    await tester.tap(find.text('دست‌نوشته'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('ink-surface')),
      const Offset(20, 30),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    expect(
      find.text('ذخیره هنوز قطعی نیست؛ دوباره ذخیره کنید.'),
      findsOneWidget,
    );
    expect(repository.notes.values.single.revision, 1);
    expect(
      tester.widget<InkCanvas>(find.byType(InkCanvas)).strokes,
      hasLength(1),
    );
    await tester.tap(find.text('متن'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('note-title')))
          .controller!
          .text,
      'draft',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('note-body')))
          .controller!
          .text,
      'private body',
    );
    repository.uncertainSave = false;
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    expect(repository.notes.values.single.revision, 2);
    expect(repository.notes.values.single.strokes, hasLength(1));
    expect(find.text('ذخیره روی دستگاه'), findsOneWidget);
  });

  testWidgets(
    'uncertain deletion retries repository after file is already gone',
    (tester) async {
      final repository = FakeNotes()..uncertainSave = true;
      await tester.pumpWidget(BcommendApp(repository: repository));
      await tester.pumpAndSettle();
      await create(tester);
      await tester.enterText(find.byKey(const Key('note-title')), 'draft');
      await tester.tap(find.byKey(const Key('save-note')));
      await tester.pumpAndSettle();
      repository.uncertainDelete = true;
      await tester.tap(find.byTooltip('حذف یادداشت'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'حذف یادداشت'));
      await tester.pumpAndSettle();
      expect(repository.notes, isEmpty);
      expect(repository.deleteCalls, 1);
      expect(
        find.textContaining('ممکن است یادداشت حذف شده باشد'),
        findsOneWidget,
      );
      expect(find.textContaining('ویرایش شما حفظ شده است'), findsNothing);
      repository.uncertainDelete = false;
      await tester.tap(find.byTooltip('حذف یادداشت'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'حذف یادداشت'));
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, 2);
      expect(find.byKey(const Key('note-title')), findsNothing);
    },
  );

  testWidgets(
    'search disables correction suggestions and personalized learning',
    (tester) async {
      await tester.pumpWidget(BcommendApp(repository: FakeNotes()));
      await tester.pumpAndSettle();
      final search = tester.widget<TextField>(find.byKey(const Key('search')));
      expect(search.autocorrect, isFalse);
      expect(search.enableSuggestions, isFalse);
      expect(search.enableIMEPersonalizedLearning, isFalse);
    },
  );

  testWidgets('empty, create, edit, explicit save, reload, search and delete', (
    tester,
  ) async {
    final repository = FakeNotes();
    await tester.pumpWidget(BcommendApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('هنوز چیزی ننوشته‌اید.'), findsOneWidget);
    await create(tester);
    await tester.enterText(find.byKey(const Key('note-title')), 'اولین نوشته');
    await tester.enterText(find.byKey(const Key('note-body')), 'متن خصوصی');
    expect(repository.notes, isEmpty);
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    expect(repository.notes.values.single.revision, 1);
    expect(find.text('ذخیره روی دستگاه'), findsOneWidget);
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();
    expect(find.text('اولین نوشته'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search')), 'ناموجود');
    await tester.pumpAndSettle();
    expect(find.text('یادداشتی پیدا نشد.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search')), 'خصوصی');
    await tester.pumpAndSettle();
    await tester.tap(find.text('اولین نوشته'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), 'ویرایش');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    expect(repository.notes.values.single.revision, 2);
    await tester.tap(find.byTooltip('حذف یادداشت'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'انصراف'));
    await tester.pumpAndSettle();
    expect(repository.notes, hasLength(1));
    await tester.tap(find.byTooltip('حذف یادداشت'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'حذف یادداشت'));
    await tester.pumpAndSettle();
    expect(repository.notes, isEmpty);
  });

  testWidgets(
    'vault failure offers retry, never a reset or writable empty vault',
    (tester) async {
      final repository = FakeNotes()..failLoad = true;
      await tester.pumpWidget(BcommendApp(repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('تلاش دوباره'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('create-note')))
            .onPressed,
        isNull,
      );
      repository.failLoad = false;
      await tester.tap(find.text('تلاش دوباره'));
      await tester.pumpAndSettle();
      expect(find.text('هنوز چیزی ننوشته‌اید.'), findsOneWidget);
      await tester.tap(find.byTooltip('تنظیمات و حریم خصوصی'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(privacyNotice),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('failed save retains edit and Save/Discard/Stay guards back', (
    tester,
  ) async {
    final repository = FakeNotes()..failSave = true;
    await tester.pumpWidget(BcommendApp(repository: repository));
    await tester.pumpAndSettle();
    await create(tester);
    await tester.enterText(find.byKey(const Key('note-title')), 'باقی بمان');
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ماندن'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره و خروج'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ذخیره نشد.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('note-title')))
          .controller!
          .text,
      'باقی بمان',
    );
    repository.failSave = false;
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), 'ذخیره نکن');
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خروج بدون ذخیره'));
    await tester.pumpAndSettle();
    expect(repository.notes.values.single.title, 'باقی بمان');
  });

  testWidgets(
    'pending save disables edits and rejects route back; failed delete stays',
    (tester) async {
      final repository = FakeNotes()..saveGate = Completer<void>();
      await tester.pumpWidget(BcommendApp(repository: repository));
      await tester.pumpAndSettle();
      await create(tester);
      await tester.enterText(find.byKey(const Key('note-title')), 'حفظ شود');
      await tester.tap(find.byKey(const Key('save-note')));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byKey(const Key('note-title'))).enabled,
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const Key('note-title')), findsOneWidget);
      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      repository.failDelete = true;
      await tester.tap(find.byTooltip('حذف یادداشت'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'حذف یادداشت'));
      await tester.pumpAndSettle();
      expect(find.textContaining('حذف نشد.'), findsOneWidget);
      expect(repository.notes, hasLength(1));
    },
  );

  testWidgets(
    'UTF16 title limit rejects excess input without truncating accepted text',
    (tester) async {
      final repository = FakeNotes();
      await tester.pumpWidget(BcommendApp(repository: repository));
      await tester.pumpAndSettle();
      await create(tester);
      final accepted = List.filled(100, '\u{1F600}').join();
      await tester.enterText(find.byKey(const Key('note-title')), accepted);
      await tester.enterText(
        find.byKey(const Key('note-title')),
        '${accepted}x',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-title')))
            .controller!
            .text,
        accepted,
      );
      expect(find.textContaining('ورودی اضافه پذیرفته نشد'), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-note')));
      await tester.pumpAndSettle();
      expect(repository.notes.values.single.title.length, 200);
    },
  );

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1200, 800),
  ]) {
    testWidgets('dark RTL scale 2 no overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      await tester.pumpWidget(BcommendApp(repository: FakeNotes()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('create-note')));
      await create(tester);
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byKey(const Key('note-title')))),
        TextDirection.rtl,
      );
      await tester.tap(find.text('دست‌نوشته'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ink-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
