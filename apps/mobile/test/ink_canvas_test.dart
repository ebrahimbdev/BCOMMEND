import 'package:bcommend_mobile/model/note.dart';
import 'package:bcommend_mobile/ui/ink_canvas.dart';
import 'package:bcommend_mobile/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<InkStroke> strokes;
  late List<String> errors;
  late List<bool> activity;

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: notebookTheme(Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => InkCanvas(
              strokes: strokes,
              onChanged: (value) => setState(() => strokes = value),
              onError: errors.add,
              onGestureChanged: activity.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    strokes = [];
    errors = [];
    activity = [];
  });

  testWidgets('gesture activity starts on down and ends after committed up', (
    tester,
  ) async {
    await mount(tester);
    expect(activity, isEmpty);
    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('ink-surface'))),
    );
    expect(activity, [true]);
    await finger.moveBy(const Offset(20, 30));
    await tester.pump();
    expect(strokes, isEmpty);
    expect(activity, [true]);
    await finger.up();
    expect(strokes, hasLength(1));
    expect(activity, [true, false]);
  });

  testWidgets(
    'multitouch activity ends only after last accepted pointer cancels',
    (tester) async {
      await mount(tester);
      final center = tester.getCenter(find.byKey(const Key('ink-surface')));
      final first = await tester.startGesture(center, pointer: 1);
      final second = await tester.startGesture(
        center + const Offset(50, 0),
        pointer: 2,
      );
      await second.moveBy(const Offset(20, 0));
      expect(activity, [true]);
      await first.up();
      expect(activity, [true]);
      await second.cancel();
      expect(activity, [true, false]);
      expect(strokes, isEmpty);
      await tester.pump();
      await tester.tap(find.byKey(const Key('ink-surface')));
      expect(activity, [true, false, true, false]);
      expect(strokes, hasLength(1));
    },
  );

  testWidgets('ignored pointers resize and dispose never publish activity', (
    tester,
  ) async {
    await mount(tester);
    final center = tester.getCenter(find.byKey(const Key('ink-surface')));
    final stylus = await tester.startGesture(
      center,
      kind: PointerDeviceKind.stylus,
      pointer: 1,
    );
    await stylus.cancel();
    expect(activity, isEmpty);
    final finger = await tester.startGesture(center, pointer: 2);
    expect(activity, [true]);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pump();
    expect(activity, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(activity, [true]);
    await finger.cancel();
    expect(activity, [true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one finger commits paper coordinates and undo removes only last stroke',
    (tester) async {
      await mount(tester);
      final center = tester.getCenter(find.byKey(const Key('ink-surface')));
      final finger = await tester.startGesture(center);
      await finger.moveBy(const Offset(20, 30));
      await finger.up();
      await tester.pump();
      expect(strokes, hasLength(1));
      expect(strokes.single.points.length, greaterThan(1));
      expect(
        strokes.single.points.every(
          (p) => p.x >= 0 && p.x <= 1000 && p.y >= 0 && p.y <= 1400,
        ),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('undo-stroke')));
      await tester.pump();
      expect(strokes, isEmpty);
    },
  );

  testWidgets(
    'second finger cancels partial ink and lifting never creates dots',
    (tester) async {
      await mount(tester);
      final center = tester.getCenter(find.byKey(const Key('ink-surface')));
      final first = await tester.startGesture(center, pointer: 1);
      await first.moveBy(const Offset(10, 10));
      final second = await tester.startGesture(
        center + const Offset(50, 0),
        pointer: 2,
      );
      await second.moveBy(const Offset(20, 0));
      await second.up();
      await first.moveBy(const Offset(20, 20));
      await first.up();
      await tester.pump();
      expect(strokes, isEmpty);
      final next = await tester.startGesture(center, pointer: 3);
      await next.moveBy(const Offset(10, 10));
      await next.up();
      await tester.pump();
      expect(strokes, hasLength(1));
    },
  );

  testWidgets(
    'pointer cancel drops partial and navigation never produces ink',
    (tester) async {
      await mount(tester);
      final center = tester.getCenter(find.byKey(const Key('ink-surface')));
      final finger = await tester.startGesture(center);
      await finger.moveBy(const Offset(20, 20));
      await finger.cancel();
      await tester.pump();
      expect(strokes, isEmpty);
      await tester.tap(find.byKey(const Key('navigation-mode')));
      await tester.pump();
      await tester.drag(
        find.byKey(const Key('ink-surface')),
        const Offset(70, 20),
      );
      await tester.pump();
      expect(strokes, isEmpty);
    },
  );

  testWidgets(
    'stroke capacity reports rejection without altering existing ink',
    (tester) async {
      strokes = List.generate(
        256,
        (_) => InkStroke(
          color: NotebookColors.ink.toARGB32(),
          width: 5,
          points: [const InkPoint(10, 10)],
        ),
      );
      await mount(tester);
      await tester.tap(find.byKey(const Key('ink-surface')));
      await tester.pump();
      expect(strokes, hasLength(256));
      expect(errors, hasLength(1));
    },
  );

  testWidgets(
    'resize cancels current draft and fresh stroke uses new viewport',
    (tester) async {
      await mount(tester);
      final finger = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('ink-surface'))),
      );
      await finger.moveBy(const Offset(20, 20));
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pump();
      await finger.up();
      await tester.pump();
      expect(strokes, isEmpty);
      await tester.tap(find.byKey(const Key('ink-surface')));
      await tester.pump();
      expect(strokes, hasLength(1));
      expect(strokes.single.points.single.x, closeTo(500, 1));
      expect(strokes.single.points.single.y, closeTo(700, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'total point budget preserves previous strokes and reports rejected draft',
    (tester) async {
      strokes = List.generate(
        4,
        (_) => InkStroke(
          color: NotebookColors.ink.toARGB32(),
          width: 5,
          points: List.generate(512, (i) => InkPoint(i.toDouble(), 100)),
        ),
      );
      await mount(tester);
      await tester.tap(find.byKey(const Key('ink-surface')));
      await tester.pump();
      expect(strokes, hasLength(4));
      expect(
        strokes.fold<int>(0, (sum, stroke) => sum + stroke.points.length),
        2048,
      );
      expect(errors, hasLength(1));
    },
  );
}
