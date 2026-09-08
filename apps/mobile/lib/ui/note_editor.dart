import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/note.dart';
import '../storage/note_repository.dart';
import 'ink_canvas.dart';
import 'theme.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.repository,
    required this.note,
    this.isNew = false,
  });
  final NoteRepository repository;
  final Note note;
  final bool isNew;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

enum _Leave { save, discard, stay }

class _NoteEditorState extends State<NoteEditor> {
  late Note _note;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late List<InkStroke> _strokes;
  late bool _dirty;
  bool _busy = false;
  bool _gestureActive = false;
  bool _allowPop = false;
  bool _leaving = false;
  bool _ink = false;
  late bool _persisted;
  String? _error;
  static const _sizeError =
      'ظرفیت ذخیره یادداشت پر است؛ ورودی اضافه پذیرفته نشد. متن یا دست‌نوشته را کمتر کنید.';

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _title = TextEditingController(text: _note.title);
    _body = TextEditingController(text: _note.body);
    _strokes = List.of(_note.strokes);
    _dirty = widget.isNew;
    _persisted = !widget.isNew;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    _dirty = true;
    _error = null;
  });

  Future<bool> _save() async {
    if (_busy || _gestureActive) return false;
    if (_title.text.length > 200 || _body.text.length > 20000) {
      setState(
        () => _error = 'عنوان حداکثر ۲۰۰ و متن حداکثر ۲۰۰۰۰ واحد نوشتاری است.',
      );
      return false;
    }
    final candidate = _note.copyWith(
      title: _title.text,
      body: _body.text,
      strokes: _strokes,
    );
    if (!candidate.fitsStorage) {
      setState(() => _error = _sizeError);
      return false;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.save(candidate);
      if (!mounted) return false;
      setState(() {
        _note = saved;
        _dirty = false;
        _busy = false;
        _persisted = true;
      });
      return true;
    } on SaveUncertain catch (error) {
      if (!mounted) return false;
      setState(() {
        _note = error.note;
        _persisted = true;
        _dirty = true;
        _busy = false;
        _error = 'ذخیره هنوز قطعی نیست؛ دوباره ذخیره کنید.';
      });
      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _busy = false;
        _error =
            'ذخیره نشد. ویرایش شما همین‌جا باقی است. فضای دستگاه، اندازه یادداشت یا تداخل نسخه را بررسی کنید و دوباره تلاش کنید.';
      });
      return false;
    }
  }

  Future<void> _exit() async {
    if (_busy || _leaving || _gestureActive) return;
    _leaving = true;
    if (_dirty) {
      final action = await showDialog<_Leave>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('تغییرات ذخیره نشده'),
          content: const Text(
            'پیش از خروج، تغییرات را روی همین دستگاه ذخیره می‌کنید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _Leave.stay),
              child: const Text('ماندن'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _Leave.discard),
              child: const Text('خروج بدون ذخیره'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _Leave.save),
              child: const Text('ذخیره و خروج'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == null ||
          action == _Leave.stay ||
          (action == _Leave.save && !await _save())) {
        _leaving = false;
        return;
      }
    }
    if (!mounted) return;
    if (_gestureActive) {
      _leaving = false;
      return;
    }
    _pop();
  }

  void _pop() {
    if (_gestureActive) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_gestureActive) {
        setState(() {
          _allowPop = false;
          _leaving = false;
        });
        return;
      }
      Navigator.of(context).pop();
    });
  }

  Future<void> _delete() async {
    if (_busy || _leaving || _gestureActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('حذف یادداشت؟'),
        content: const Text(
          'یادداشت و تغییرات ذخیره‌نشده آن حذف می‌شود. این کار قابل بازگشت نیست.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف یادداشت'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy || _gestureActive) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_persisted) await widget.repository.delete(_note.id);
      if (mounted) _pop();
    } on DeleteUncertain catch (_) {
      if (mounted) {
        setState(() {
          _persisted = true;
          _busy = false;
          _error =
              'حذف هنوز قطعی نیست؛ ممکن است یادداشت حذف شده باشد. دوباره حذف کنید.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'حذف نشد. یادداشت و ویرایش شما حفظ شده است؛ دوباره تلاش کنید.';
        });
      }
    }
  }

  TextInputFormatter _limit(
    int max, {
    required bool title,
  }) => TextInputFormatter.withFunction((oldValue, newValue) {
    if (_busy) return oldValue;
    if (newValue.text.length > max) {
      setState(
        () => _error =
            'حد مجاز این بخش $max واحد نوشتاری است؛ ورودی اضافه پذیرفته نشد.',
      );
      return oldValue;
    }
    final candidate = _note.copyWith(
      title: title ? newValue.text : _title.text,
      body: title ? _body.text : newValue.text,
      strokes: _strokes,
    );
    if (!candidate.fitsStorage) {
      setState(() => _error = _sizeError);
      return oldValue;
    }
    return newValue;
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop && !_gestureActive,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      body: NotebookFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy || _gestureActive ? null : _exit,
                    tooltip: 'بازگشت',
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _busy
                            ? 'در حال ذخیره / پردازش…'
                            : _gestureActive
                            ? 'برای ذخیره، انگشت را بردارید'
                            : _dirty
                            ? 'ذخیره نشده'
                            : 'ذخیره روی دستگاه',
                        style: Theme.of(context).textTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('save-note'),
                    onPressed: _busy || _gestureActive || !_dirty
                        ? null
                        : _save,
                    tooltip: 'ذخیره روی دستگاه',
                    icon: const Icon(Icons.save_outlined),
                  ),
                  IconButton(
                    onPressed: _busy || _gestureActive ? null : _delete,
                    tooltip: 'حذف یادداشت',
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            if (_busy)
              const LinearProgressIndicator(semanticsLabel: 'در حال پردازش'),
            if (_error != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 112),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            AbsorbPointer(
              absorbing: _busy,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _busy || _gestureActive
                          ? null
                          : () {
                              if (_busy || _gestureActive) return;
                              setState(() => _ink = false);
                            },
                      child: Semantics(
                        selected: !_ink,
                        child: Text(!_ink ? 'متن •' : 'متن'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _busy || _gestureActive
                          ? null
                          : () {
                              if (_busy || _gestureActive) return;
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(() => _ink = true);
                            },
                      child: Semantics(
                        selected: _ink,
                        child: Text(_ink ? 'دست‌نوشته •' : 'دست‌نوشته'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AbsorbPointer(
                absorbing: _busy,
                child: _ink
                    ? InkCanvas(
                        enabled: !_busy,
                        strokes: _strokes,
                        onGestureChanged: (active) =>
                            setState(() => _gestureActive = active),
                        onChanged: (value) {
                          if (!_busy) {
                            if (!_note
                                .copyWith(
                                  title: _title.text,
                                  body: _body.text,
                                  strokes: value,
                                )
                                .fitsStorage) {
                              setState(() => _error = _sizeError);
                              return;
                            }
                            setState(() {
                              _strokes = value;
                              _dirty = true;
                              _error = null;
                            });
                          }
                        },
                        onError: (value) => setState(() => _error = value),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          TextField(
                            key: const Key('note-title'),
                            controller: _title,
                            enabled: !_busy,
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            inputFormatters: [_limit(200, title: true)],
                            onChanged: (_) => _changed(),
                            textInputAction: TextInputAction.next,
                            style: Theme.of(context).textTheme.headlineSmall,
                            decoration: const InputDecoration(
                              labelText: 'عنوان',
                              helperText: 'حداکثر ۲۰۰ واحد نوشتاری',
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            key: const Key('note-body'),
                            controller: _body,
                            enabled: !_busy,
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            inputFormatters: [_limit(20000, title: false)],
                            onChanged: (_) => _changed(),
                            minLines: 8,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              labelText: 'متن یادداشت',
                              alignLabelWithHint: true,
                              hintText: 'اینجا بنویسید…',
                              helperText: 'حداکثر ۲۰۰۰۰ واحد نوشتاری',
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'ذخیره خودکار فعال نیست. پیش از بستن برنامه، دکمه ذخیره را بزنید.',
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
