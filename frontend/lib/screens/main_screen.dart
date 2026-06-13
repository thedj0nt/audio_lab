import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_providers.dart';
import '../widgets/sidebar_panel.dart';
import '../widgets/status_footer.dart';
import '../widgets/mobile_bottom_nav_bar.dart';
import '../core/theme.dart';
import 'library_workspace.dart';
import 'workstation_workspace.dart';
import 'settings_workspace.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;
    final currentTab = ref.watch(currentTabProvider);
    final colors = ref.watch(themeColorsProvider);

    final mainContent = Scaffold(
      backgroundColor: colors.background,
      drawer: isDesktop
          ? null
          : const Drawer(
              backgroundColor: Color(0xFF0A0A0C),
              child: SidebarPanel(),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isDesktop) const SidebarPanel(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Responsive Header block
                        _buildTopHeader(context, ref, isDesktop, colors),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                              return Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            child: _buildActiveWorkspace(currentTab),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const StatusFooter(),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop ? null : const MobileBottomNavBar(),
    );

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space):
            PlayPauseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (PlayPauseIntent intent) {
              // Ignore play/pause if a text field is currently focused
              final focusNode = FocusManager.instance.primaryFocus;
              final bool isTextFieldFocused = focusNode != null &&
                  (focusNode.context?.widget is EditableText ||
                      focusNode.context
                              ?.findAncestorWidgetOfExactType<EditableText>() !=
                          null);

              if (!isTextFieldFocused) {
                final playerState = ref.read(multiStemPlayerProvider);
                if (playerState.isReady) {
                  final notifier = ref.read(multiStemPlayerProvider.notifier);
                  if (playerState.isPlaying) {
                    notifier.pause();
                  } else {
                    notifier.play();
                  }
                }
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: mainContent,
        ),
      ),
    );
  }

  Widget _buildActiveWorkspace(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return const LibraryWorkspace();
      case 1:
        return const WorkstationWorkspace();
      case 2:
        return const SettingsWorkspace();
      default:
        return const LibraryWorkspace();
    }
  }

  Widget _buildTopHeader(BuildContext context, WidgetRef ref, bool isDesktop,
      AppThemeColors colors) {
    final currentTab = ref.watch(currentTabProvider);
    final selectedProject = ref.watch(selectedProjectProvider);

    if (currentTab == 1 && selectedProject != null) {
      // Workstation view header (HUD: BPM, Key/Scale)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(bottom: BorderSide(color: colors.border, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (!isDesktop) ...[
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: Icon(Icons.menu_rounded, color: colors.textPrimary),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  'BPM',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  selectedProject['bpm']?.toString() ?? '--',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  'SCALE',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  (selectedProject['scale'] as String).isNotEmpty
                      ? selectedProject['scale']
                      : '--',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            // Header actions: Displaying active project title
            Text(
              (selectedProject['title'] ?? 'Session').toString().toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    // Library view header
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isDesktop) ...[
                Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu_rounded, color: colors.textPrimary),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                Text(
                  currentTab == 0
                      ? 'LIBRARY'
                      : currentTab == 1
                          ? 'WORKSTATION'
                          : 'SETTINGS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: colors.accent,
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              // Search Input Box (Desktop only)
              if (isDesktop && currentTab == 0)
                SizedBox(
                  width: 200,
                  height: 32,
                  child: TextField(
                    style: TextStyle(fontSize: 11, color: colors.textPrimary),
                    onChanged: (val) {
                      ref.read(searchQueryProvider.notifier).state = val;
                    },
                    decoration: InputDecoration(
                      hintText: 'SEARCH SAMPLES...',
                      hintStyle: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.4),
                        fontSize: 10,
                        letterSpacing: 1.0,
                        fontFamily: 'monospace',
                      ),
                      fillColor: colors.card,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      suffixIcon: Icon(Icons.search_rounded,
                          color: colors.textSecondary.withValues(alpha: 0.4),
                          size: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: colors.accent),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
