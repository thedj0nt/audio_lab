import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AudioLabApp(),
    ),
  );
}

class AudioLabApp extends ConsumerWidget {
  const AudioLabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Audio Lab',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightThemeData,
      darkTheme: darkThemeData,
      home: const MainScreen(),
    );
  }
}
