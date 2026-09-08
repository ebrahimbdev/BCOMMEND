import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'storage/note_repository.dart';
import 'ui/notes_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BcommendApp(repository: EncryptedNoteRepository()));
}

class BcommendApp extends StatelessWidget {
  const BcommendApp({super.key, required this.repository});

  final NoteRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'BCOMMEND | دفتر خصوصی',
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: notebookTheme(Brightness.light),
    darkTheme: notebookTheme(Brightness.dark),
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: NotesScreen(repository: repository),
  );
}
