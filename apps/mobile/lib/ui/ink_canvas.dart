import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../model/note.dart';
import 'theme.dart';

/// A bounded pilot paper, not an infinite canvas. Strokes use paper coordinates.
class InkCanvas extends StatefulWidget {
  const InkCanvas({
    super.key,
    required this.strokes,
    required this.onChanged,
    required this.onError,
    this.onGestureChanged,
    this.enabled = true,
  });
  final List<InkStroke> strokes;
  final ValueChanged<List<InkStroke>> onChanged;
  final ValueChanged<String> onError;
  final ValueChanged<bool>? onGestureChanged;
  final bool enabled;

  @override
  State<InkCanvas> createState() => _InkCanvasState();
}

class _InkCanvasState extends State<InkCanvas> {
  static const _paper = Size(1000, 1400);
  final Map<int, Offset> _pointers = {};
  final List<InkPoint> _draft = [];
  Size _viewport = Size.zero;
  double _fit = 1;
  double _zoom = 1;
  Offset _translation = Offset.zero;
  bool _navigation = false;
  // Multi-touch/cancel must never become a new stroke on the remaining finger.
  bool _blocked = false;
  int _color = 0;

  @override
  void didUpdateWidget(covariant InkCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _draft.clear();
      _blocked = _pointers.isNotEmpty;
    }
  }

  double get _scale => _fit * _zoom;

  void _fitPaper(Size size) {
    _viewport = size;
    _fit = math.max(
      0.001,
      math.min(size.width / _paper.width, size.height / _paper.height),
    );
    _zoom = 1;
    _translation = Offset(
      (size.width - _paper.width * _scale) / 2,
      (size.height - _paper.height * _scale) / 2,
    );
    _draft.clear();
    _blocked = _pointers.isNotEmpty;
  }

  void _bound() {
    final width = _paper.width * _scale;
    final height = _paper.height * _scale;
    _translation = Offset(
      _translation.dx
          .clamp(
            -width + math.min(32, width),
            math.max(0, _viewport.width - 32),
          )
          .toDouble(),
      _translation.dy
          .clamp(
            -height + math.min(32, height),
            math.max(0, _viewport.height - 32),
          )
          .toDouble(),
    );
  }

  void _zoomAt(double factor, Offset oldCenter, Offset newCenter) {
    final world = (oldCenter - _translation) / _scale;
    _zoom = (_zoom * factor).clamp(0.2, 4.0).toDouble();
    _translation = newCenter - world * _scale;
    _bound();
  }

  void _point(Offset local) {
    final world = (local - _translation) / _scale;
    if (!world.dx.isFinite || !world.dy.isFinite) return;
    final point = InkPoint(
      world.dx.clamp(0, _paper.width).toDouble(),
      world.dy.clamp(0, _paper.height).toDouble(),
    );
    if (_draft.isNotEmpty) {
      final last = _draft.last;
      if ((Offset(last.x, last.y) - Offset(point.x, point.y)).distance < 2) {
        return;
      }
    }
    final count = widget.strokes.fold<int>(
      0,
      (sum, stroke) => sum + stroke.points.length,
    );
    if (widget.strokes.length >= 256 ||
        _draft.length >= 512 ||
        count + _draft.length >= 2048) {
      _draft.clear();
      _blocked = true;
      widget.onError(
        'ظرفیت دست‌نوشته پر شد (۲۵۶ خط، ۲۰۴۸ نقطه، ۵۱۲ نقطه در هر خط). خط ناتمام پذیرفته نشد؛ خط کوتاه‌تر بکشید یا واگرد بزنید.',
      );
      return;
    }
    _draft.add(point);
  }

  bool _accept(PointerDownEvent event) =>
      event.kind == PointerDeviceKind.touch ||
      (event.kind == PointerDeviceKind.mouse &&
          event.buttons == kPrimaryMouseButton);

  void _down(PointerDownEvent event) {
    if (!mounted || !widget.enabled || !_accept(event)) return;
    final first = _pointers.isEmpty;
    setState(() {
      _pointers[event.pointer] = event.localPosition;
      if (_pointers.length > 1) {
        _draft.clear();
        _blocked = true;
      } else if (!_navigation && !_blocked) {
        final world = (event.localPosition - _translation) / _scale;
        if ((Offset.zero & _paper).contains(world)) {
          _point(event.localPosition);
        } else {
          _blocked = true;
        }
      }
    });
    if (first) widget.onGestureChanged?.call(true);
  }

  void _move(PointerMoveEvent event) {
    if (!mounted || !widget.enabled || !_pointers.containsKey(event.pointer)) {
      return;
    }
    setState(() {
      final before = _pointers.values.toList();
      final previous = _pointers[event.pointer]!;
      _pointers[event.pointer] = event.localPosition;
      final after = _pointers.values.toList();
      if (_pointers.length >= 2) {
        final oldDistance = (before[0] - before[1]).distance;
        final newDistance = (after[0] - after[1]).distance;
        _zoomAt(
          oldDistance > 1 ? newDistance / oldDistance : 1,
          (before[0] + before[1]) / 2,
          (after[0] + after[1]) / 2,
        );
      } else if (_navigation) {
        _translation += event.localPosition - previous;
        _bound();
      } else if (!_blocked) {
        _point(event.localPosition);
      }
    });
  }

  void _up(PointerUpEvent event) {
    if (!mounted || !_pointers.containsKey(event.pointer)) return;
    if (widget.enabled && !_navigation && !_blocked && _pointers.length == 1) {
      _point(event.localPosition);
      if (_draft.isNotEmpty) {
        widget.onChanged([
          ...widget.strokes,
          InkStroke(
            color: NotebookColors.strokeColors[_color].toARGB32(),
            width: 5,
            points: List.of(_draft),
          ),
        ]);
      }
    }
    setState(() {
      _draft.clear();
      _pointers.remove(event.pointer);
      if (_pointers.isEmpty) _blocked = false;
    });
    if (_pointers.isEmpty) widget.onGestureChanged?.call(false);
  }

  void _cancel(PointerCancelEvent event) {
    if (!mounted || !_pointers.containsKey(event.pointer)) return;
    setState(() {
      _draft.clear();
      _pointers.remove(event.pointer);
      _blocked = _pointers.isNotEmpty;
    });
    if (_pointers.isEmpty) widget.onGestureChanged?.call(false);
  }

  void _tool(VoidCallback action) => setState(() {
    _draft.clear();
    _blocked = _pointers.isNotEmpty;
    action();
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              key: const Key('draw-mode'),
              tooltip: 'حالت نوشتن با انگشت',
              isSelected: !_navigation,
              onPressed: () => _tool(() => _navigation = false),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: const Key('navigation-mode'),
              tooltip: 'حالت جابه‌جایی کاغذ',
              isSelected: _navigation,
              onPressed: () => _tool(() => _navigation = true),
              icon: const Icon(Icons.pan_tool_outlined),
            ),
            IconButton(
              key: const Key('undo-stroke'),
              tooltip: 'واگرد آخرین خط',
              onPressed: widget.strokes.isEmpty || _pointers.isNotEmpty
                  ? null
                  : () => widget.onChanged(
                      widget.strokes.sublist(0, widget.strokes.length - 1),
                    ),
              icon: const Icon(Icons.undo),
            ),
            for (var i = 0; i < NotebookColors.strokeColors.length; i++)
              IconButton(
                tooltip: ['جوهر تیره', 'جوهر سبز', 'جوهر آجری'][i],
                isSelected: _color == i,
                onPressed: () => _tool(() => _color = i),
                icon: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: NotebookColors.strokeColors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: _color == i
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            IconButton(
              tooltip: 'بزرگ‌نمایی',
              onPressed: () => _tool(
                () => _zoomAt(
                  1.25,
                  _viewport.center(Offset.zero),
                  _viewport.center(Offset.zero),
                ),
              ),
              icon: const Icon(Icons.zoom_in),
            ),
            IconButton(
              tooltip: 'کوچک‌نمایی',
              onPressed: () => _tool(
                () => _zoomAt(
                  0.8,
                  _viewport.center(Offset.zero),
                  _viewport.center(Offset.zero),
                ),
              ),
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: 'نمایش تمام کاغذ',
              onPressed: () => _tool(() => _fitPaper(_viewport)),
              icon: const Icon(Icons.fit_screen),
            ),
            IconButton(
              tooltip: 'جابه‌جایی به راست',
              onPressed: () => _tool(() {
                _translation += const Offset(64, 0);
                _bound();
              }),
              icon: const Icon(Icons.arrow_right),
            ),
            IconButton(
              tooltip: 'جابه‌جایی به چپ',
              onPressed: () => _tool(() {
                _translation += const Offset(-64, 0);
                _bound();
              }),
              icon: const Icon(Icons.arrow_left),
            ),
            IconButton(
              tooltip: 'جابه‌جایی به بالا',
              onPressed: () => _tool(() {
                _translation += const Offset(0, -64);
                _bound();
              }),
              icon: const Icon(Icons.arrow_drop_up),
            ),
            IconButton(
              tooltip: 'جابه‌جایی به پایین',
              onPressed: () => _tool(() {
                _translation += const Offset(0, 64);
                _bound();
              }),
              icon: const Icon(Icons.arrow_drop_down),
            ),
          ],
        ),
      ),
      SizedBox(
        height: 40,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _navigation
                ? 'جابه‌جایی • یک انگشت: حرکت؛ دو انگشت: بزرگ‌نمایی'
                : 'کاغذ آزمایشی • یک انگشت: نوشتن؛ دو انگشت: حرکت و بزرگ‌نمایی',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            // Refit on rotation/resizing; never retain a transform for an obsolete rect.
            if (size != _viewport) _fitPaper(size);
            return Semantics(
              label: _navigation
                  ? 'کاغذ، حالت جابه‌جایی'
                  : 'کاغذ، حالت نوشتن با انگشت',
              hint:
                  'برای یادداشت قابل خواندن با صفحه‌خوان، از بخش متن استفاده کنید.',
              child: ClipRect(
                child: Listener(
                  key: const Key('ink-surface'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _cancel,
                  child: CustomPaint(
                    size: size,
                    painter: _PaperPainter(
                      strokes: widget.strokes,
                      draft: List.of(_draft),
                      color: NotebookColors.strokeColors[_color],
                      scale: _scale,
                      translation: _translation,
                      surround: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _PaperPainter extends CustomPainter {
  _PaperPainter({
    required this.strokes,
    required this.draft,
    required this.color,
    required this.scale,
    required this.translation,
    required this.surround,
  });
  final List<InkStroke> strokes;
  final List<InkPoint> draft;
  final Color color;
  final double scale;
  final Offset translation;
  final Color surround;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = surround);
    canvas.save();
    canvas.translate(translation.dx, translation.dy);
    canvas.scale(scale);
    const paper = Rect.fromLTWH(0, 0, 1000, 1400);
    canvas.clipRect(paper);
    // Paper stays warm in dark mode so persisted ink colors remain legible.
    canvas.drawRect(paper, Paint()..color = NotebookColors.paper);
    final grid = Paint()
      ..color = NotebookColors.teal.withValues(alpha: 0.13)
      ..strokeWidth = 1;
    for (double x = 50; x < 1000; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, 1400), grid);
    }
    for (double y = 50; y < 1400; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(1000, y), grid);
    }
    for (final stroke in strokes) {
      _stroke(canvas, stroke.points, Color(stroke.color), stroke.width);
    }
    _stroke(canvas, draft, color, 5);
    canvas.restore();
  }

  void _stroke(
    Canvas canvas,
    List<InkPoint> points,
    Color color,
    double width,
  ) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (points.length == 1) {
      canvas.drawCircle(
        Offset(points.first.x, points.first.y),
        width / 2,
        paint,
      );
      return;
    }
    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) => true;
}
