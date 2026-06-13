import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_providers.dart';
import '../widgets/daw_waveform.dart';
import '../widgets/task_status_progress_banner.dart';
import '../core/theme.dart';
import '../core/utils.dart';

class WorkstationWorkspace extends ConsumerStatefulWidget {
  const WorkstationWorkspace({super.key});

  @override
  ConsumerState<WorkstationWorkspace> createState() =>
      _WorkstationWorkspaceState();
}

class _WorkstationWorkspaceState extends ConsumerState<WorkstationWorkspace> {
  double? _dragValue;
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
    final playerState = ref.watch(multiStemPlayerProvider);
    final selectedProject = ref.watch(selectedProjectProvider);
    final masterVol = ref.watch(masterVolumeProvider);
    final colors = ref.watch(themeColorsProvider);

    if (selectedProject == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.album_rounded,
                size: 80,
                color: colors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'Workstation is Empty',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select a session from your Library tab to load the mix workspace.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go to Library'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ref.read(currentTabProvider.notifier).state = 0;
                },
              ),
            ],
          ),
        ),
      );
    }

    final List<dynamic> allTracks = selectedProject['tracks'] ?? [];
    final List<dynamic> tracks = (selectedProject['status'] == 'Completed')
        ? (allTracks.isNotEmpty ? allTracks.sublist(1) : <dynamic>[])
        : allTracks;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Loading Indicator
            if (playerState.isLoading || !playerState.isReady)
              const TaskStatusProgressBanner(),

            // 1. MASTER ANALYZER Waveform Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'MASTER ANALYZER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Beautiful custom DAW Waveform
                  DAWWaveform(
                    progress: playerState.progress,
                    isPlaying: playerState.isPlaying,
                  ),
                  const SizedBox(height: 12),

                  // Timeline bar HUD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(playerState.currentPosition.inSeconds),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        'LIVE PLAYBACK',
                        style: TextStyle(
                          fontSize: 9,
                          color: colors.accent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        formatDuration(playerState.totalDuration.inSeconds),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Scrubber Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      activeTrackColor: colors.accent,
                      inactiveTrackColor: colors.border,
                      thumbColor: colors.accent,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayColor: colors.accent.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      value: _dragValue ?? playerState.progress,
                      onChanged: playerState.isReady
                          ? (val) {
                              setState(() {
                                _dragValue = val;
                              });
                            }
                          : null,
                      onChangeEnd: playerState.isReady
                          ? (val) {
                              ref
                                  .read(multiStemPlayerProvider.notifier)
                                  .seek(val)
                                  .then((_) {
                                if (mounted) {
                                  setState(() {
                                    _dragValue = null;
                                  });
                                }
                              });
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Responsive Mixer Section
            LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth >= 700;
                final mixerWidget = Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'STEM MIXER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'ACTIVE CHANNELS: ${tracks.length.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.accent,
                              letterSpacing: 1.0,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      tracks.isEmpty && !playerState.isLoading
                          ? const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('No stems loaded')))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: tracks.length,
                              itemBuilder: (context, index) {
                                final track = tracks[index];
                                return _buildMixerStrip(ref, colors, track);
                              },
                            ),
                    ],
                  ),
                );

                final controlsWidget = Column(
                  children: [
                    // Playback Controllers
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.shuffle_rounded, size: 18),
                                color: colors.textSecondary,
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded,
                                    size: 24),
                                color: colors.textPrimary,
                                onPressed: playerState.isReady
                                    ? () => ref
                                        .read(multiStemPlayerProvider.notifier)
                                        .seek(0.0)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // Large Square Play/Pause button
                              GestureDetector(
                                onTap: playerState.isReady
                                    ? () {
                                        if (playerState.isPlaying) {
                                          ref
                                              .read(multiStemPlayerProvider
                                                  .notifier)
                                              .pause();
                                        } else {
                                          ref
                                              .read(multiStemPlayerProvider
                                                  .notifier)
                                              .play();
                                        }
                                      }
                                    : null,
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: playerState.isReady
                                        ? colors.accent
                                        : colors.border,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: playerState.isReady
                                        ? [
                                            BoxShadow(
                                              color: colors.accent
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    playerState.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded,
                                    size: 24),
                                color: colors.textPrimary,
                                onPressed: null, // Disabled in DAW mockup
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.loop_rounded, size: 18),
                                color: colors.textSecondary,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Master Volume Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MASTER VOL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textSecondary,
                                  letterSpacing: 1.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                '${(masterVol * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.accent,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              activeTrackColor: colors.accent,
                              inactiveTrackColor: colors.border,
                              thumbColor: colors.accent,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: masterVol,
                              onChanged: (val) {
                                ref.read(masterVolumeProvider.notifier).state =
                                    val;
                                ref
                                    .read(multiStemPlayerProvider.notifier)
                                    .updateMasterVolume(val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: controlsWidget),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: mixerWidget),
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    controlsWidget,
                    const SizedBox(height: 16),
                    mixerWidget,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMixerStrip(
      WidgetRef ref, AppThemeColors colors, Map<String, dynamic> track) {
    final int trackId = track['id'];
    final String trackName = track['name'] ?? 'Stem';

    final playerState = ref.watch(multiStemPlayerProvider);
    final volumes = ref.watch(stemVolumesProvider);
    final mutes = ref.watch(stemMutesProvider);
    final solos = ref.watch(stemSolosProvider);

    final trackVol = volumes[trackId] ?? 0.75;
    final isMuted = mutes[trackId] ?? false;
    final isSoloed = solos[trackId] ?? false;

    // Convert linear volume to decibels fader indicator
    final String dbLabel = isMuted ? 'MUTED' : formatDb(trackVol);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trackName.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  letterSpacing: 1.0,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                dbLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isMuted ? colors.accent : colors.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Mute Button styled as 'M' tag fader button
              GestureDetector(
                onTap: playerState.isReady
                    ? () {
                        final currentlyMuted = isMuted;
                        ref
                            .read(stemMutesProvider.notifier)
                            .toggleMute(trackId);
                        ref
                            .read(multiStemPlayerProvider.notifier)
                            .setTrackMute(trackId, !currentlyMuted);
                      }
                    : null,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isMuted
                        ? colors.accent.withValues(alpha: 0.15)
                        : colors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isMuted ? colors.accent : colors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: isMuted
                          ? colors.accent
                          : colors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Solo Button styled as 'S' tag fader button
              GestureDetector(
                onTap: playerState.isReady
                    ? () {
                        ref
                            .read(stemSolosProvider.notifier)
                            .toggleSolo(trackId);
                        ref
                            .read(multiStemPlayerProvider.notifier)
                            .updateAllTrackVolumes();
                      }
                    : null,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSoloed
                        ? colors.accent.withValues(alpha: 0.15)
                        : colors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSoloed ? colors.accent : colors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'S',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: isSoloed
                          ? colors.accent
                          : colors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(ref.context).copyWith(
                    trackHeight: 2,
                    activeTrackColor: colors.accent,
                    inactiveTrackColor: colors.background,
                    thumbColor: colors.accent,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: isMuted ? 0.0 : trackVol,
                    onChanged: (isMuted || !playerState.isReady)
                        ? null
                        : (val) {
                            ref
                                .read(stemVolumesProvider.notifier)
                                .setVolume(trackId, val);
                            ref
                                .read(multiStemPlayerProvider.notifier)
                                .setTrackVolume(trackId, val);
                          },
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
