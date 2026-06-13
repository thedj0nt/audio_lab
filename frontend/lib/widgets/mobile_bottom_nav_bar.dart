import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_providers.dart';
import '../core/theme.dart';

class MobileBottomNavBar extends ConsumerWidget {
  const MobileBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final colors = ref.watch(themeColorsProvider);

    return BottomNavigationBar(
      backgroundColor: colors.background,
      selectedItemColor: colors.accent,
      unselectedItemColor: colors.textSecondary.withValues(alpha: 0.5),
      currentIndex: currentTab,
      onTap: (index) {
        ref.read(currentTabProvider.notifier).state = index;
      },
      selectedLabelStyle: const TextStyle(
          fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
      unselectedLabelStyle:
          const TextStyle(fontFamily: 'monospace', fontSize: 10),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.library_music_rounded),
          label: 'LIBRARY',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.album_rounded),
          label: 'MIXER',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_rounded),
          label: 'SETTINGS',
        ),
      ],
    );
  }
}
