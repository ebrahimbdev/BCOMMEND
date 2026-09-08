import 'package:flutter/material.dart';

abstract final class NotebookColors {
  static const paper = Color(0xFFF7F4EC);
  static const ink = Color(0xFF242D2C);
  static const teal = Color(0xFF326C65);
  static const rust = Color(0xFF9A4937);
  static const strokeColors = [ink, teal, rust];
}

ThemeData notebookTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: NotebookColors.teal,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF9DD0C4) : NotebookColors.teal,
        onPrimary: dark ? const Color(0xFF123830) : Colors.white,
        surface: dark ? const Color(0xFF1A211F) : NotebookColors.paper,
        onSurface: dark ? const Color(0xFFF0EEE6) : NotebookColors.ink,
        onSurfaceVariant: dark
            ? const Color(0xFFC2C9C2)
            : const Color(0xFF535E58),
        outline: dark ? const Color(0xFF919E96) : const Color(0xFF738078),
        outlineVariant: dark
            ? const Color(0xFF46524B)
            : const Color(0xFFCED2C8),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    // No downloaded fonts: Android's native fallback supplies Persian glyphs.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      helperMaxLines: 3,
      contentPadding: EdgeInsets.all(16),
    ),
  );
}

class NotebookFrame extends StatelessWidget {
  const NotebookFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SizedBox.expand(child: child),
      ),
    ),
  );
}
