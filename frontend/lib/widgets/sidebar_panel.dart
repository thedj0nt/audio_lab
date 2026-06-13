import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/audio_providers.dart';

class SidebarPanel extends ConsumerWidget {
  const SidebarPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final selectedProject = ref.watch(selectedProjectProvider);
    final colors = ref.watch(themeColorsProvider);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          right: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 24,
                  color: colors.accent,
                ),
                const SizedBox(width: 12),
                Text(
                  'ECHO LAB',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Session Card (Only display if a project is loaded)
          if (selectedProject != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.waves_rounded,
                        color: colors.accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedProject['title'] ?? 'Session',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '48kHz / 24-bit',
                          style: TextStyle(
                            color: colors.textSecondary.withValues(alpha: 0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Sidebar Navigation items
          _buildSidebarLink(
            ref,
            colors,
            index: 0,
            icon: Icons.library_music_rounded,
            label: 'Library',
            isActive: currentTab == 0,
          ),
          const SizedBox(height: 8),
          _buildSidebarLink(
            ref,
            colors,
            index: 1,
            icon: Icons.tune_rounded,
            label: 'Workstation',
            isActive: currentTab == 1,
          ),
          const SizedBox(height: 8),
          _buildSidebarLink(
            ref,
            colors,
            index: 2,
            icon: Icons.settings_rounded,
            label: 'Settings',
            isActive: currentTab == 2,
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSidebarLink(
    WidgetRef ref,
    AppThemeColors colors, {
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () {
        ref.read(currentTabProvider.notifier).state = index;
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? colors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isActive
              ? Border(
                  left: BorderSide(color: colors.accent, width: 3),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? colors.textPrimary : colors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
