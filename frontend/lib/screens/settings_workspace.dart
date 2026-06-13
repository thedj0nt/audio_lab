import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';

class SettingsWorkspace extends ConsumerStatefulWidget {
  const SettingsWorkspace({super.key});

  @override
  ConsumerState<SettingsWorkspace> createState() => _SettingsWorkspaceState();
}

class _SettingsWorkspaceState extends ConsumerState<SettingsWorkspace> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Configure AI extraction engines and interface modes.',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Theme Selector Section
            _buildSection(
              colors,
              title: 'INTERFACE COLOR MODE',
              children: [
                _buildThemeToggleRow(context, ref, colors),
              ],
            ),
            const SizedBox(height: 24),

            // Config Readouts Section
            _buildSection(
              colors,
              title: 'AI SEPARATION CONFIG',
              children: [
                _buildSettingRow(context, colors, 'Default Model', 'HTDemucs v4 (Hybrid Transformer)'),
                _buildSettingRow(context, colors, '6-Stem Model', 'HTDemucs 6s (Vocals, Drums, Bass, Other, Guitar, Piano)'),
                _buildSettingRow(context, colors, 'Backend Mode', 'Dockerized Celery + Redis Queues'),
              ],
            ),
            const SizedBox(height: 24),

            // Environment Details Section
            _buildSection(
              colors,
              title: 'COMPUTE ENVIRONMENT',
              children: [
                _buildSettingRow(context, colors, 'Separation Device', 'CUDA GPU / Cloud Cluster'),
                _buildSettingRow(context, colors, 'Compute Budget', 'Unlimited (Development License)'),
                _buildSettingRow(context, colors, 'Engine Version', 'v2.4.0-production'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(AppThemeColors colors, {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: colors.accent,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingRow(BuildContext context, AppThemeColors colors, String label, String value) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 550;

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildThemeToggleRow(BuildContext context, WidgetRef ref, AppThemeColors colors) {
    final themeMode = ref.watch(themeModeProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 550;

    if (isWide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Interface Color Theme',
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              _buildThemeButton(ref, colors, 'LIGHT', themeMode == ThemeMode.light, () {
                ref.read(themeModeProvider.notifier).state = ThemeMode.light;
              }),
              const SizedBox(width: 8),
              _buildThemeButton(ref, colors, 'DARK', themeMode == ThemeMode.dark, () {
                ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
              }),
            ],
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interface Color Theme',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildThemeButton(ref, colors, 'LIGHT', themeMode == ThemeMode.light, () {
                  ref.read(themeModeProvider.notifier).state = ThemeMode.light;
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildThemeButton(ref, colors, 'DARK', themeMode == ThemeMode.dark, () {
                  ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
                }),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildThemeButton(WidgetRef ref, AppThemeColors colors, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : colors.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? colors.accent : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
