import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/note.dart';
import '../storage/note_repository.dart';
import 'note_editor.dart';
import 'theme.dart';

const privacyNotice =
    'نسخه آزمایشی، فقط روی این دستگاه. حذف برنامه یا از دست‌رفتن کلید می‌تواند اطلاعات را غیرقابل‌بازیابی کند. همگام‌سازی و بازیابی هنوز فعال نیست.';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.repository});
  final NoteRepository repository;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _loading = true;
  bool _failed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final notes = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _open([Note? note]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NoteEditor(
          repository: widget.repository,
          note: note ?? Note(id: const Uuid().v4(), updatedAt: DateTime.now()),
          isNew: note == null,
        ),
      ),
    );
    if (mounted) await _load();
  }

  void _privacy() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('حریم خصوصی'),
      content: const Text(privacyNotice),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final visible =
        _notes
            .where(
              (n) => '${n.title}\n${n.body}'.toLowerCase().contains(
                _query.trim().toLowerCase(),
              ),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      body: NotebookFrame(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'BCOMMEND',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _privacy,
                          tooltip: 'تنظیمات و حریم خصوصی',
                          icon: const Icon(Icons.tune_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'دفتر خصوصی',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('نسخه آزمایشی • فقط روی این دستگاه'),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('search'),
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: const InputDecoration(
                        labelText: 'جست‌وجو در یادداشت‌ها',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('create-note'),
                      onPressed: _loading || _failed ? null : () => _open(),
                      icon: const Icon(Icons.add),
                      label: const Text('یادداشت تازه'),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'در حال خواندن یادداشت‌ها',
                    ),
                  ),
                ),
              )
            else if (_failed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'باز کردن دفتر ممکن نشد. اطلاعات پاک نشده است؛ دوباره تلاش کنید.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('تلاش دوباره'),
                      ),
                    ],
                  ),
                ),
              )
            else if (visible.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.edit_note_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _notes.isEmpty
                            ? 'هنوز چیزی ننوشته‌اید.'
                            : 'یادداشتی پیدا نشد.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _notes.isEmpty
                            ? 'از یک جمله شروع کنید؛ یا با انگشت روی کاغذ بنویسید.'
                            : 'عبارت دیگری را جست‌وجو کنید.',
                      ),
                      if (_notes.isEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(privacyNotice),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final note = visible[index];
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 4,
                          ),
                          title: Text(
                            note.title.trim().isEmpty
                                ? 'بدون عنوان'
                                : note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            note.body.isEmpty
                                ? (note.strokes.isEmpty
                                      ? 'یادداشت خالی'
                                      : 'دست‌نوشته')
                                : note.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => _open(note),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
