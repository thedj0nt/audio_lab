import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/audio_providers.dart';
import '../core/theme.dart';
import '../widgets/separation_options_dialog.dart';

class LibraryWorkspace extends ConsumerWidget {
  const LibraryWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final selectedProject = ref.watch(selectedProjectProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;

    final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
    final viewMode = ref.watch(libraryViewModeProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final modelFilter = ref.watch(modelFilterProvider);
    final colors = ref.watch(themeColorsProvider);
    final isUploading = ref.watch(isUploadingProvider);

    var newTrackViewChangeWidget = Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.black,
              side: BorderSide(color: colors.accent, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            onPressed:
                isUploading ? null : () => _handleNewTrackUpload(context, ref),
            icon: isUploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: colors.textPrimary,
                  ),
            label: Text(
              isUploading ? 'UPLOADING...' : 'NEW TRACK',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ),
          // if (isDesktop) ...[
          const SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: viewMode == 'list'
                  ? colors.textPrimary
                  : colors.textSecondary,
              backgroundColor:
                  viewMode == 'list' ? colors.accent : Colors.transparent,
              side: BorderSide(
                  color: viewMode == 'list' ? colors.accent : colors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () {
              ref.read(libraryViewModeProvider.notifier).state = 'list';
            },
            child: const Text('LIST',
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: viewMode == 'grid'
                  ? colors.textPrimary
                  : colors.textSecondary,
              backgroundColor:
                  viewMode == 'grid' ? colors.accent : Colors.transparent,
              side: BorderSide(
                  color: viewMode == 'grid' ? colors.accent : colors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () {
              ref.read(libraryViewModeProvider.notifier).state = 'grid';
            },
            child: const Text('GRID',
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold)),
          ),
        ],
        // ],
      ),
    );

    var children = [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Music Library',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage all your tracks.',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          if (!isDesktop) ...[newTrackViewChangeWidget],
        ],
      ),
      if (isDesktop) newTrackViewChangeWidget
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Music Library Header Title & Actions (NEW TRACK, LIST/GRID toggles)
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: children,
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 22,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: children,
                ),
          const SizedBox(height: 24),

          // Filters bar Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
            child: projectsAsync.when(
              data: (projects) {
                // 1. Dynamic filtering logic
                final filtered = projects.where((proj) {
                  final title = (proj['title'] ?? '').toString().toLowerCase();
                  final status =
                      (proj['status'] ?? '').toString().toLowerCase();
                  final stemsStr =
                      (proj['stems'] ?? '').toString().toLowerCase();

                  if (searchQuery.isNotEmpty && !title.contains(searchQuery)) {
                    return false;
                  }

                  if (statusFilter != 'ALL') {
                    final isMastered = status == 'completed';
                    final isInProgress =
                        status == 'processing' || status == 'pending';
                    final isFailed = status == 'failed';
                    if (statusFilter == 'MASTERED' && !isMastered) {
                      return false;
                    }
                    if (statusFilter == 'IN PROGRESS' && !isInProgress) {
                      return false;
                    }
                    if (statusFilter == 'FAILED' && !isFailed) {
                      return false;
                    }
                  }

                  if (modelFilter != 'ALL') {
                    final has6s = stemsStr.contains('guitar') ||
                        stemsStr.contains('piano');
                    if (modelFilter == '6-STEM' && !has6s) {
                      return false;
                    }
                    if (modelFilter == '4-STEM' && has6s) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                return SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDropdownFilter(
                            context,
                            ref,
                            colors,
                            'STATUS',
                            statusFilter,
                            ['ALL', 'MASTERED', 'IN PROGRESS', 'FAILED'],
                            (val) => ref
                                .read(statusFilterProvider.notifier)
                                .state = val,
                          ),
                          const SizedBox(width: 8),
                          _buildDropdownFilter(
                            context,
                            ref,
                            colors,
                            'ENGINE',
                            modelFilter,
                            ['ALL', '4-STEM', '6-STEM'],
                            (val) => ref
                                .read(modelFilterProvider.notifier)
                                .state = val,
                          ),
                        ],
                      ),
                      Text(
                        '${filtered.length} TRACKS MATCHED',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 1)),
              error: (_, __) => Text('ERROR LOADING FILTERS',
                  style: TextStyle(
                      color: colors.accent,
                      fontSize: 10,
                      fontFamily: 'monospace')),
            ),
          ),
          const SizedBox(height: 16),

          // Search Input Box (Mobile only)
          if (!isDesktop) ...[
            Container(
              height: 36,
              margin: const EdgeInsets.only(bottom: 16),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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

          // Tracks Panel View (List or Grid)
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
            child: projectsAsync.when(
              data: (projects) {
                // Apply filter to calculate list to render
                final filteredProjects = projects.where((proj) {
                  final title = (proj['title'] ?? '').toString().toLowerCase();
                  final status =
                      (proj['status'] ?? '').toString().toLowerCase();
                  final stemsStr =
                      (proj['stems'] ?? '').toString().toLowerCase();

                  if (searchQuery.isNotEmpty && !title.contains(searchQuery)) {
                    return false;
                  }

                  if (statusFilter != 'ALL') {
                    final isMastered = status == 'completed';
                    final isInProgress =
                        status == 'processing' || status == 'pending';
                    final isFailed = status == 'failed';
                    if (statusFilter == 'MASTERED' && !isMastered) {
                      return false;
                    }
                    if (statusFilter == 'IN PROGRESS' && !isInProgress) {
                      return false;
                    }
                    if (statusFilter == 'FAILED' && !isFailed) {
                      return false;
                    }
                  }

                  if (modelFilter != 'ALL') {
                    final has6s = stemsStr.contains('guitar') ||
                        stemsStr.contains('piano');
                    if (modelFilter == '6-STEM' && !has6s) {
                      return false;
                    }
                    if (modelFilter == '4-STEM' && has6s) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (filteredProjects.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Center(
                      child: Text(
                        'No matching tracks in library. Click "NEW TRACK" to separate stems.',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Render Grid Layout
                if (viewMode == 'grid') {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: filteredProjects.length,
                      itemBuilder: (context, index) {
                        final project = filteredProjects[index];
                        final isLoaded = selectedProject != null &&
                            selectedProject['id'] == project['id'];
                        return LibraryTrackGridCard(
                            project: project, isLoaded: isLoaded);
                      },
                    ),
                  );
                }

                // Mobile Layout or List Layout (Default)
                if (!isDesktop) {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredProjects.length,
                    itemBuilder: (context, index) {
                      final project = filteredProjects[index];
                      final isLoaded = selectedProject != null &&
                          selectedProject['id'] == project['id'];
                      return _buildMobileTrackTile(
                          context, ref, colors, project, index, isLoaded);
                    },
                  );
                }

                // Desktop Table View
                return Column(
                  children: [
                    const LibraryTableHeader(),
                    Divider(color: colors.border, height: 1),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredProjects.length,
                      itemBuilder: (context, index) {
                        final project = filteredProjects[index];
                        final isLoaded = selectedProject != null &&
                            selectedProject['id'] == project['id'];
                        return LibraryTrackRow(
                            index: index, project: project, isLoaded: isLoaded);
                      },
                    ),
                  ],
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.accent)),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: colors.accent, size: 32),
                      const SizedBox(height: 12),
                      Text('Error: $err',
                          style: TextStyle(
                              color: colors.textPrimary, fontSize: 12)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent),
                        onPressed: () =>
                            ref.read(projectsProvider.notifier).loadProjects(),
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(
    BuildContext context,
    WidgetRef ref,
    AppThemeColors colors,
    String label,
    String currentValue,
    List<String> options,
    Function(String) onSelected,
  ) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: colors.card,
      offset: const Offset(0, 32),
      itemBuilder: (context) => options.map((opt) {
        final bool isSel = opt.toUpperCase() == currentValue.toUpperCase();
        return PopupMenuItem<String>(
          value: opt,
          child: Text(
            opt.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: isSel ? colors.accent : colors.textPrimary,
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${currentValue.toUpperCase()}',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: colors.textSecondary, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTrackTile(
    BuildContext context,
    WidgetRef ref,
    AppThemeColors colors,
    Map<String, dynamic> project,
    int index,
    bool isLoaded,
  ) {
    final status = project['status'] ?? 'Pending';
    final bpm = project['bpm'];
    final scale = project['scale'];
    final title = project['title'] ?? 'Untitled';

    Color statusColor = colors.textSecondary;
    String statusText = status.toUpperCase();
    if (status == 'Completed') {
      statusColor = colors.accent;
      statusText = 'MASTERED';
    } else if (status == 'Processing' || status == 'Pending') {
      statusColor = colors.textPrimary;
      statusText = 'IN PROGRESS';
    } else if (status == 'Failed') {
      statusColor = Colors.redAccent;
      statusText = 'FAILED';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: statusColor, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${bpm ?? '--'} BPM',
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: colors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    scale.isNotEmpty ? scale : '--',
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: colors.accent,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        size: 18),
                    onPressed: () =>
                        _confirmDeleteProject(context, ref, colors, project),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                    ),
                    onPressed: () {
                      ref.read(selectedProjectProvider.notifier).state =
                          project;
                      ref
                          .read(multiStemPlayerProvider.notifier)
                          .loadProject(project);
                      ref.read(currentTabProvider.notifier).state = 1;
                    },
                    child: const Text('WORKSTATION',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LibraryTableHeader Helper Widget
// -----------------------------------------------------------------------------
class LibraryTableHeader extends StatelessWidget {
  const LibraryTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('#', style: _headerStyle)),
          Expanded(child: Text('TITLE / ARTIST', style: _headerStyle)),
          SizedBox(width: 80, child: Text('BPM', style: _headerStyle)),
          SizedBox(width: 80, child: Text('KEY', style: _headerStyle)),
          SizedBox(width: 120, child: Text('STATUS', style: _headerStyle)),
          SizedBox(width: 150, child: Text('ACTIONS', style: _headerStyle)),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: Color(0xFF4A4A52),
    letterSpacing: 1.5,
    fontFamily: 'monospace',
  );
}

// -----------------------------------------------------------------------------
// LibraryTrackRow Helper Widget
// -----------------------------------------------------------------------------
class LibraryTrackRow extends ConsumerWidget {
  final int index;
  final Map<String, dynamic> project;
  final bool isLoaded;

  const LibraryTrackRow({
    super.key,
    required this.index,
    required this.project,
    required this.isLoaded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = project['status'] ?? 'Pending';
    final bpm = project['bpm'];
    final scale = project['scale'];
    final title = project['title'] ?? 'Untitled';
    final colors = ref.watch(themeColorsProvider);

    Color statusColor = colors.textSecondary;
    String statusText = status.toUpperCase();
    if (status == 'Completed') {
      statusColor = colors.accent;
      statusText = 'MASTERED';
    } else if (status == 'Processing' || status == 'Pending') {
      statusColor = colors.textPrimary;
      statusText = 'IN PROGRESS';
    } else if (status == 'Failed') {
      statusColor = Colors.redAccent;
      statusText = 'FAILED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Index
          SizedBox(
            width: 40,
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: 'monospace',
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Title / Artist
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isLoaded
                        ? Icons.play_circle_fill_rounded
                        : Icons.audiotrack_rounded,
                    color: isLoaded ? colors.accent : colors.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Echo Engine Core',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // BPM
          SizedBox(
            width: 80,
            child: Text(
              bpm != null ? bpm.toString() : '--',
              style: TextStyle(
                fontSize: 12,
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // KEY
          SizedBox(
            width: 80,
            child: Text(
              scale != null && scale.isNotEmpty ? scale : '--',
              style: TextStyle(
                fontSize: 12,
                color: scale != null && scale.isNotEmpty
                    ? colors.accent
                    : colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // STATUS
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 90,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: statusColor, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // ACTIONS
          SizedBox(
            width: 150,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLoaded && ref.watch(multiStemPlayerProvider).isPlaying
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_arrow_rounded,
                    color: colors.textPrimary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (isLoaded) {
                      final notifier =
                          ref.read(multiStemPlayerProvider.notifier);
                      final playerState = ref.read(multiStemPlayerProvider);
                      if (playerState.isPlaying) {
                        notifier.pause();
                      } else {
                        notifier.play();
                      }
                    } else {
                      _loadAndPlay(ref);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => _loadAndPlay(ref),
                  child: const Text('WORKSTATION',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadAndPlay(WidgetRef ref) {
    ref.read(selectedProjectProvider.notifier).state = project;
    ref.read(multiStemPlayerProvider.notifier).loadProject(project);
    ref.read(currentTabProvider.notifier).state = 1;
  }
}

// -----------------------------------------------------------------------------
// LibraryTrackGridCard Helper Widget
// -----------------------------------------------------------------------------
class LibraryTrackGridCard extends ConsumerWidget {
  final Map<String, dynamic> project;
  final bool isLoaded;

  const LibraryTrackGridCard({
    super.key,
    required this.project,
    required this.isLoaded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final status = project['status'] ?? 'Pending';
    final bpm = project['bpm'];
    final scale = project['scale'];
    final title = project['title'] ?? 'Untitled';
    final stems = project['stems'] ?? '';

    Color statusColor = colors.textSecondary;
    String statusText = status.toUpperCase();
    if (status == 'Completed') {
      statusColor = colors.accent;
      statusText = 'MASTERED';
    } else if (status == 'Processing' || status == 'Pending') {
      statusColor = colors.textPrimary;
      statusText = 'IN PROGRESS';
    } else if (status == 'Failed') {
      statusColor = Colors.redAccent;
      statusText = 'FAILED';
    }

    return GestureDetector(
      onDoubleTap: () {
        ref.read(selectedProjectProvider.notifier).state = project;
        ref.read(multiStemPlayerProvider.notifier).loadProject(project);
        ref.read(currentTabProvider.notifier).state = 1;
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLoaded ? colors.accent : colors.border,
            width: isLoaded ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon / Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.album_rounded,
                  color: isLoaded ? colors.accent : colors.textSecondary,
                  size: 24,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor, width: 0.5),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 8,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Title
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // BPM & Key
            Row(
              children: [
                Text(
                  '${bpm ?? '--'} BPM',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  scale.isNotEmpty ? scale : '--',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stems.isNotEmpty
                      ? '${stems.split(',').length} STEMS'
                      : '4 STEMS',
                  style: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: Colors.redAccent.withValues(alpha: 0.8),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () =>
                      _confirmDeleteProject(context, ref, colors, project),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Global Deletion Handler Helper
// -----------------------------------------------------------------------------
void _confirmDeleteProject(
  BuildContext context,
  WidgetRef ref,
  AppThemeColors colors,
  Map<String, dynamic> project,
) {
  final int projectId = project['id'];
  final String projectTitle = project['title'] ?? 'Session';

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return AlertDialog(
        backgroundColor: colors.card,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.accent),
            const SizedBox(width: 10),
            Text(
              'Delete Session',
              style: TextStyle(
                  color: colors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$projectTitle"?\n\n⚠️ Once deleted, this action CANNOT be undone, and all track stems will be physically deleted from the server.',
          style:
              TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.5),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: colors.border),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();

              try {
                final client = ref.read(apiClientProvider);
                await client.deleteProject(projectId);

                final selectedProject = ref.read(selectedProjectProvider);
                if (selectedProject != null &&
                    selectedProject['id'] == projectId) {
                  ref.read(multiStemPlayerProvider.notifier).unload();
                  ref.read(selectedProjectProvider.notifier).state = null;
                }

                ref.read(projectsProvider.notifier).loadProjects();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF2CB67D),
                      content:
                          Text('Session "$projectTitle" deleted successfully.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.redAccent,
                      content: Text('Failed to delete session: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}

// -----------------------------------------------------------------------------
// Global Upload Handler Helper
// -----------------------------------------------------------------------------
Future<void> _handleNewTrackUpload(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      // Auto-extract and beautify song title
      final filename = file.name;
      String defaultTitle = filename;
      if (filename.contains('.')) {
        defaultTitle = filename
            .split('.')
            .sublist(0, filename.split('.').length - 1)
            .join('.');
      }
      defaultTitle = defaultTitle
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .replaceAll('.', ' ')
          .trim();
      if (defaultTitle.isNotEmpty) {
        defaultTitle =
            defaultTitle.split(' ').where((w) => w.isNotEmpty).map((word) {
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
      }

      // Show the separation options dialog modal
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext ctx) {
            return SeparationOptionsDialog(
              pickedFile: file,
              defaultTitle: defaultTitle,
              onUploadTriggered: (title, stems) async {
                // Trigger upload sequence
                ref.read(isUploadingProvider.notifier).state = true;
                try {
                  final client = ref.read(apiClientProvider);
                  final newProj =
                      await client.uploadProject(title, [file], stems: stems);

                  ref.read(projectsProvider.notifier).loadProjects();
                  ref.read(selectedProjectProvider.notifier).state = newProj;

                  ref
                      .read(multiStemPlayerProvider.notifier)
                      .loadProject(newProj);

                  // Switch to workstation tab
                  ref.read(currentTabProvider.notifier).state = 1;

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF2CB67D),
                        content: Text('Separation queued for "$title"!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.redAccent,
                        content: Text('Upload failed: $e'),
                      ),
                    );
                  }
                } finally {
                  ref.read(isUploadingProvider.notifier).state = false;
                }
              },
            );
          },
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error choosing audio: $e')),
      );
    }
  }
}
