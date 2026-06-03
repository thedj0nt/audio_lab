import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'api_client.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AudioLabApp(),
    ),
  );
}

class AudioLabApp extends StatelessWidget {
  const AudioLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0E17),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7F5AF0),
          brightness: Brightness.dark,
          primary: const Color(0xFF7F5AF0),
          secondary: const Color(0xFF2CB67D),
          surface: const Color(0xFF16161A),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF16161A),
          elevation: 4,
          margin: EdgeInsets.zero,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF7F5AF0),
          inactiveTrackColor: Color(0xFF242629),
          thumbColor: Color(0xFF2CB67D),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// State Management (Riverpod Providers)
// -----------------------------------------------------------------------------

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// Projects loading state
class ProjectsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final ApiClient _client;
  ProjectsNotifier(this._client) : super(const AsyncValue.loading()) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    state = const AsyncValue.loading();
    try {
      final projects = await _client.fetchProjects();
      state = AsyncValue.data(projects);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }
}

final projectsProvider =
    StateNotifierProvider<ProjectsNotifier, AsyncValue<List<dynamic>>>((ref) {
  return ProjectsNotifier(ref.watch(apiClientProvider));
});

// Currently selected project
final selectedProjectProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

// Screen selector (0: Mix Board, 1: Projects/Uploads)
final currentTabProvider = StateProvider<int>((ref) => 0);

// Master Volume state
final masterVolumeProvider = StateProvider<double>((ref) => 0.8);

// Track Stem Volumes state (Map: trackId -> volume)
class StemVolumesController extends StateNotifier<Map<int, double>> {
  StemVolumesController() : super({});

  void setVolume(int trackId, double volume) {
    state = {...state, trackId: volume};
  }

  void reset(List<dynamic> tracks) {
    final Map<int, double> initial = {};
    for (var track in tracks) {
      initial[track['id'] as int] = 0.75; // standard initial volume
    }
    state = initial;
  }
}

final stemVolumesProvider =
    StateNotifierProvider<StemVolumesController, Map<int, double>>((ref) {
  return StemVolumesController();
});

// Track Stem Mutes state (Map: trackId -> isMuted)
class StemMutesController extends StateNotifier<Map<int, bool>> {
  StemMutesController() : super({});

  void toggleMute(int trackId) {
    final current = state[trackId] ?? false;
    state = {...state, trackId: !current};
  }

  void reset(List<dynamic> tracks) {
    final Map<int, bool> initial = {};
    for (var track in tracks) {
      initial[track['id'] as int] = false;
    }
    state = initial;
  }
}

final stemMutesProvider =
    StateNotifierProvider<StemMutesController, Map<int, bool>>((ref) {
  return StemMutesController();
});

// Upload form state
final pickedFilesProvider = StateProvider<List<PlatformFile>>((ref) => []);
final projectTitleControllerProvider =
    Provider<TextEditingController>((ref) => TextEditingController());
final isUploadingProvider = StateProvider<bool>((ref) => false);

// -----------------------------------------------------------------------------
// Real Native Audio Player State & Controller (HTTP 206 Supported)
// -----------------------------------------------------------------------------

class MultiStemPlayerState {
  final bool isPlaying;
  final bool isLoading;
  final bool isReady;
  final double progress; // 0.0 to 1.0
  final Duration currentPosition;
  final Duration totalDuration;
  final String statusMessage;
  final Map<int, String> trackStatuses; // trackId -> status string

  MultiStemPlayerState({
    required this.isPlaying,
    required this.isLoading,
    required this.isReady,
    required this.progress,
    required this.currentPosition,
    required this.totalDuration,
    required this.statusMessage,
    required this.trackStatuses,
  });

  factory MultiStemPlayerState.initial() {
    return MultiStemPlayerState(
      isPlaying: false,
      isLoading: false,
      isReady: false,
      progress: 0.0,
      currentPosition: Duration.zero,
      totalDuration: Duration.zero,
      statusMessage: 'Ready to load session',
      trackStatuses: {},
    );
  }

  MultiStemPlayerState copyWith({
    bool? isPlaying,
    bool? isLoading,
    bool? isReady,
    double? progress,
    Duration? currentPosition,
    Duration? totalDuration,
    String? statusMessage,
    Map<int, String>? trackStatuses,
  }) {
    return MultiStemPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isReady: isReady ?? this.isReady,
      progress: progress ?? this.progress,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      statusMessage: statusMessage ?? this.statusMessage,
      trackStatuses: trackStatuses ?? this.trackStatuses,
    );
  }
}

class MultiStemPlayerNotifier extends StateNotifier<MultiStemPlayerState> {
  final Ref _ref;
  final Map<int, AudioPlayer> _players = {};
  final Map<int, StreamSubscription> _stateSubscriptions = {};
  StreamSubscription<Duration>? _positionSubscription;

  MultiStemPlayerNotifier(this._ref) : super(MultiStemPlayerState.initial());

  /// Sets up a player instance for each track stem and initiates HTTP 206 buffering
  Future<void> loadProject(Map<String, dynamic> project) async {
    final String projectTitle = project['title'] ?? 'Song Session';
    print('[CONSOLE] 📂 Initializing loaded audio project: "$projectTitle"');

    // Clear any active playing instances
    await _cleanup();

    state = state.copyWith(
      isLoading: true,
      isReady: false,
      isPlaying: false,
      statusMessage: 'Loading audio stems...',
      trackStatuses: {},
    );

    final List<dynamic> tracks = project['tracks'] ?? [];
    if (tracks.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'No audio tracks found in this project.',
      );
      print(
          '[CONSOLE] ⚠️ Load Aborted: The project session contains no audio tracks.');
      return;
    }

    // Set initial loading states
    final Map<int, String> initialStatuses = {};
    for (var track in tracks) {
      initialStatuses[track['id'] as int] = 'loading';
    }
    state = state.copyWith(trackStatuses: initialStatuses);

    bool hasErrors = false;
    final List<Future<void>> loadFutures = [];

    for (var track in tracks) {
      final int trackId = track['id'];
      final String trackName = track['name'] ?? 'Stem';

      // Connect specifically to our HTTP 206 Partial Content Stream endpoint
      // Extract active host dynamically from backend file URL to prevent emulator host mismatch
      String streamUrl = '${ApiClient.baseUrl}/api/tracks/$trackId/stream/';
      final String? fileUrl = track['file'];
      if (fileUrl != null && fileUrl.startsWith('http')) {
        try {
          final uri = Uri.parse(fileUrl);
          final portSuffix = uri.hasPort ? ':${uri.port}' : '';
          streamUrl =
              '${uri.scheme}://${uri.host}$portSuffix/api/tracks/$trackId/stream/';
        } catch (e) {
          print('[CONSOLE] ⚠️ Mismatch parsing file URL: $e');
        }
      }

      print(
          '[CONSOLE] 🧪 Creating native AudioPlayer for track: "$trackName" (ID: $trackId)');
      final player = AudioPlayer();
      _players[trackId] = player;

      // EXHAUSTIVE DEBUG STATE LISTENERS
      _stateSubscriptions[trackId] = player.playerStateStream.listen(
        (playerState) {
          final processingState = playerState.processingState;
          final playing = playerState.playing;

          print('[AudioPlayer Listener - Track: "$trackName" (ID: $trackId)]');
          print('  -> state.playing: $playing');
          print('  -> state.processingState: $processingState');

          String statusText = 'idle';

          if (processingState == ProcessingState.loading) {
            statusText = 'loading';
            print(
                '[CONSOLE] ⏳ Track "$trackName" (ID: $trackId) status: LOADING stream from -> $streamUrl');
          } else if (processingState == ProcessingState.buffering) {
            statusText = 'buffering';
            print(
                '[CONSOLE] 🌀 Track "$trackName" (ID: $trackId) status: BUFFERING HTTP 206 range blocks');
          } else if (processingState == ProcessingState.ready) {
            statusText = 'ready';
            print(
                '[CONSOLE] ✅ Track "$trackName" (ID: $trackId) status: READY (Fully buffered & aligned)');
          } else if (processingState == ProcessingState.completed) {
            statusText = 'completed';
            print(
                '[CONSOLE] ⏹️ Track "$trackName" (ID: $trackId) status: COMPLETED playback');
          }

          // Update local status map
          final currentStatuses = Map<int, String>.from(state.trackStatuses);
          currentStatuses[trackId] = statusText;
          state = state.copyWith(trackStatuses: currentStatuses);

          // Dynamically check master buffering ready state
          _evaluateOverallState();
        },
        onError: (Object e) {
          print(
              '[CONSOLE] ❌ Track "$trackName" (ID: $trackId) encountered dynamic parsing error: $e');

          final currentStatuses = Map<int, String>.from(state.trackStatuses);
          currentStatuses[trackId] = 'error: $e';
          state = state.copyWith(
            trackStatuses: currentStatuses,
            statusMessage: 'Error parsing stem: $trackName',
          );
        },
      );

      // Load futures list
      loadFutures.add(
        Future(() async {
          try {
            print(
                '[CONSOLE] ⚡ Dispensing range request setUrl call for: "$trackName" -> $streamUrl');

            // just_audio automatically communicates with range headers (HTTP 206)
            await player.setUrl(streamUrl);

            // Sync current mixer controls
            final double initialVol =
                _ref.read(stemVolumesProvider)[trackId] ?? 0.75;
            final double masterVol = _ref.read(masterVolumeProvider);
            final isMuted = _ref.read(stemMutesProvider)[trackId] ?? false;

            await player.setVolume(isMuted ? 0.0 : initialVol * masterVol);
            print(
                '[CONSOLE] 🔊 Stem "$trackName" volume initialized to ${isMuted ? 0.0 : initialVol * masterVol}');
          } catch (e) {
            hasErrors = true;
            print(
                '[CONSOLE] ❌ Failed to compile network resource for "$trackName": $e');
            final currentStatuses = Map<int, String>.from(state.trackStatuses);
            currentStatuses[trackId] = 'failed';
            state = state.copyWith(trackStatuses: currentStatuses);
          }
        }),
      );
    }

    // Await parallel initialization of all streams
    await Future.wait(loadFutures);

    if (hasErrors) {
      state = state.copyWith(
        isLoading: false,
        isReady: false,
        statusMessage: 'Some audio stems failed to buffer properly.',
      );
      print(
          '[CONSOLE] ⚠️ Multi-stem alignment loaded with partial network block errors.');
      return;
    }

    // Set up master tracker timeline listening on the first track stem
    if (_players.isNotEmpty) {
      final masterPlayer = _players.values.first;

      // Calculate overall max duration returned from media assets
      Duration totalDur = Duration.zero;
      for (var player in _players.values) {
        if (player.duration != null && player.duration! > totalDur) {
          totalDur = player.duration!;
        }
      }

      state = state.copyWith(totalDuration: totalDur);
      print('[CONSOLE] 🕒 Multi-stem play duration calculated: $totalDur');

      _positionSubscription = masterPlayer.positionStream.listen((pos) {
        if (totalDur.inMilliseconds > 0) {
          final progress = pos.inMilliseconds / totalDur.inMilliseconds;
          state = state.copyWith(
            currentPosition: pos,
            progress: progress.clamp(0.0, 1.0),
          );
        }
      });
    }

    state = state.copyWith(
      isLoading: false,
      isReady: true,
      statusMessage: 'All stems successfully buffered & ready!',
    );
    print('[CONSOLE] 🎉 Multi-stem mixing desk is ready.');
  }

  void _evaluateOverallState() {
    bool loading = false;
    bool buffering = false;
    bool allReady = true;

    for (var player in _players.values) {
      final pState = player.processingState;
      if (pState == ProcessingState.loading) {
        loading = true;
        allReady = false;
      } else if (pState == ProcessingState.buffering) {
        buffering = true;
      } else if (pState != ProcessingState.ready &&
          pState != ProcessingState.completed) {
        allReady = false;
      }
    }

    state = state.copyWith(
      isLoading: loading,
      isReady: allReady && !loading,
      statusMessage: loading
          ? 'Loading stems...'
          : buffering
              ? 'Buffering stems...'
              : 'Stems synchronized and ready.',
    );
  }

  /// Begins concurrent playback across all players in parallel
  Future<void> play() async {
    if (!state.isReady) {
      print('[CONSOLE] ⚠️ Play command ignored: desk is not ready.');
      return;
    }
    print(
        '[CONSOLE] ▶️ Playback active. Triggering all streams simultaneously.');
    state = state.copyWith(isPlaying: true);
    await Future.wait(_players.values.map((p) => p.play()));
  }

  /// Pauses all streams
  Future<void> pause() async {
    print('[CONSOLE] ⏸️ Playback paused. Halting all streams.');
    state = state.copyWith(isPlaying: false);
    await Future.wait(_players.values.map((p) => p.pause()));
  }

  /// Stops all play states and seeks back to 0.0
  Future<void> stop() async {
    print('[CONSOLE] ⏹️ Stop command. Rewinding and resetting stems.');
    state = state.copyWith(isPlaying: false);
    await Future.wait(_players.values.map((p) => p.pause()));
    await Future.wait(_players.values.map((p) => p.seek(Duration.zero)));
    state = state.copyWith(progress: 0.0, currentPosition: Duration.zero);
  }

  /// Seeks all players in unison to ensure sync
  Future<void> seek(double progress) async {
    if (!state.isReady) return;
    final totalMs = state.totalDuration.inMilliseconds;
    final targetMs = (progress * totalMs).toInt();
    final targetDuration = Duration(milliseconds: targetMs);

    print('[CONSOLE] 🔍 Seeking all stems in unison to: $targetDuration');
    await Future.wait(_players.values.map((p) => p.seek(targetDuration)));
    state = state.copyWith(
      progress: progress,
      currentPosition: targetDuration,
    );
  }

  /// Sets volume dynamically on individual track channels
  void setTrackVolume(int trackId, double volume) {
    final player = _players[trackId];
    if (player != null) {
      final double masterVol = _ref.read(masterVolumeProvider);
      final isMuted = _ref.read(stemMutesProvider)[trackId] ?? false;
      if (!isMuted) {
        player.setVolume(volume * masterVol);
        print(
            '[CONSOLE] 🔊 Slider change (Track: $trackId) to: $volume (Gain output: ${volume * masterVol})');
      }
    }
  }

  /// Mutes and unmutes players cleanly without losing slider state settings
  void setTrackMute(int trackId, bool isMuted) {
    final player = _players[trackId];
    if (player != null) {
      if (isMuted) {
        player.setVolume(0.0);
        print('[CONSOLE] 🔇 Track muted (Track: $trackId)');
      } else {
        final double trackVol = _ref.read(stemVolumesProvider)[trackId] ?? 0.75;
        final double masterVol = _ref.read(masterVolumeProvider);
        player.setVolume(trackVol * masterVol);
        print(
            '[CONSOLE] 🔊 Track unmuted (Track: $trackId, restored gain: ${trackVol * masterVol})');
      }
    }
  }

  /// Modifies master slider mix gain across all unmuted tracks
  void updateMasterVolume(double masterVolume) {
    _players.forEach((trackId, player) {
      final isMuted = _ref.read(stemMutesProvider)[trackId] ?? false;
      if (!isMuted) {
        final double trackVol = _ref.read(stemVolumesProvider)[trackId] ?? 0.75;
        player.setVolume(trackVol * masterVolume);
      }
    });
    print(
        '[CONSOLE] 🎚️ Master Gain changed to: $masterVolume. All unmuted channels scaled.');
  }

  /// Disposes active player objects
  Future<void> unload() async {
    print('[CONSOLE] 📂 Closing project stem slots.');
    await _cleanup();
    state = MultiStemPlayerState.initial();
  }

  Future<void> _cleanup() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    for (var sub in _stateSubscriptions.values) {
      await sub.cancel();
    }
    _stateSubscriptions.clear();

    for (var player in _players.values) {
      await player.stop();
      await player.dispose();
    }
    _players.clear();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

final multiStemPlayerProvider =
    StateNotifierProvider<MultiStemPlayerNotifier, MultiStemPlayerState>((ref) {
  return MultiStemPlayerNotifier(ref);
});

// -----------------------------------------------------------------------------
// UI Navigation Scaffold
// -----------------------------------------------------------------------------

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0E17),
              Color(0xFF1D1B26),
              Color(0xFF0D0C12),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, ref),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: currentTab == 0 ? const MixerTab() : const UploadTab(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF242629), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentTab,
          onTap: (index) => ref.read(currentTabProvider.notifier).state = index,
          backgroundColor: const Color(0xFF16161A),
          selectedItemColor: const Color(0xFF7F5AF0),
          unselectedItemColor: const Color(0xFF94A1B2),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_rounded),
              label: 'Mixing Desk',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.queue_music_rounded),
              label: 'Dashboard & Upload',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final selectedProject = ref.watch(selectedProjectProvider);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F5AF0), Color(0xFF2CB67D)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.multitrack_audio_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AUDIO LAB',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    selectedProject != null
                        ? 'Project: ${selectedProject['title']}'
                        : 'No Project Loaded',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A1B2),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (selectedProject != null)
            IconButton(
              icon: const Icon(Icons.eject_rounded, color: Colors.redAccent),
              tooltip: 'Unload Project',
              onPressed: () {
                ref.read(multiStemPlayerProvider.notifier).unload();
                ref.read(selectedProjectProvider.notifier).state = null;
              },
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: Studio Mixer Screen
// -----------------------------------------------------------------------------

class MixerTab extends ConsumerWidget {
  const MixerTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProject = ref.watch(selectedProjectProvider);
    final playerState = ref.watch(multiStemPlayerProvider);

    if (selectedProject == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.album_rounded,
                size: 80,
                color: const Color(0xFF242629).withValues(alpha: 0.8),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ready to Mix?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Head over to the Dashboard tab to select a song session or upload your own multi-track stem recordings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A1B2),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Go to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F5AF0),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  ref.read(currentTabProvider.notifier).state = 1;
                },
              ),
            ],
          ),
        ),
      );
    }

    final List<dynamic> tracks = selectedProject['tracks'] ?? [];

    return Column(
      children: [
        // Master mixing strip
        const MasterSection(),

        // Track Status Box during Loading/Buffering
        if (playerState.isLoading || !playerState.isReady)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF7F5AF0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF7F5AF0).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF7F5AF0)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    playerState.statusMessage,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        // Custom DAW track strips
        Expanded(
          child: tracks.isEmpty
              ? const Center(
                  child: Text('This project has no audio tracks uploaded.'),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return TrackMixerStrip(track: track);
                  },
                ),
        ),
      ],
    );
  }
}

// Master Playback controls
class MasterSection extends ConsumerWidget {
  const MasterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(multiStemPlayerProvider);
    final masterVol = ref.watch(masterVolumeProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242629), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MASTER MIX DESK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2CB67D),
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Volume ${(masterVol * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A1B2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Play/Pause Master
              GestureDetector(
                onTap: playerState.isReady
                    ? () {
                        if (playerState.isPlaying) {
                          ref.read(multiStemPlayerProvider.notifier).pause();
                        } else {
                          ref.read(multiStemPlayerProvider.notifier).play();
                        }
                      }
                    : null,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: playerState.isReady ? null : const Color(0xFF242629),
                    gradient: playerState.isReady
                        ? LinearGradient(
                            colors: playerState.isPlaying
                                ? [
                                    const Color(0xFF2CB67D),
                                    const Color(0xFF1D8C55)
                                  ]
                                : [
                                    const Color(0xFF7F5AF0),
                                    const Color(0xFF6246E5)
                                  ],
                          )
                        : null,
                    boxShadow: playerState.isReady
                        ? [
                            BoxShadow(
                              color: (playerState.isPlaying
                                      ? const Color(0xFF2CB67D)
                                      : const Color(0xFF7F5AF0))
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    playerState.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: playerState.isReady
                        ? Colors.white
                        : const Color(0xFF94A1B2),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Stop button
              IconButton(
                icon: const Icon(Icons.stop_rounded, color: Colors.white),
                onPressed: playerState.isReady
                    ? () => ref.read(multiStemPlayerProvider.notifier).stop()
                    : null,
              ),
              const SizedBox(width: 8),

              // Master Slider
              Expanded(
                child: Slider(
                  value: masterVol,
                  activeColor: const Color(0xFF2CB67D),
                  onChanged: (val) {
                    ref.read(masterVolumeProvider.notifier).state = val;
                    ref
                        .read(multiStemPlayerProvider.notifier)
                        .updateMasterVolume(val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Timeline indicator
          Row(
            children: [
              Text(
                _formatTime(playerState.currentPosition.inSeconds),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: playerState.progress,
                  onChanged: playerState.isReady
                      ? (val) {
                          ref.read(multiStemPlayerProvider.notifier).seek(val);
                        }
                      : null,
                ),
              ),
              Text(
                _formatTime(playerState.totalDuration.inSeconds),
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF94A1B2)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// Track Strip Item
class TrackMixerStrip extends ConsumerWidget {
  final Map<String, dynamic> track;
  const TrackMixerStrip({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int trackId = track['id'];
    final String trackName = track['name'] ?? 'Stem';

    final playerState = ref.watch(multiStemPlayerProvider);
    final volumes = ref.watch(stemVolumesProvider);
    final mutes = ref.watch(stemMutesProvider);

    final trackVol = volumes[trackId] ?? 0.75;
    final isMuted = mutes[trackId] ?? false;

    // Get track specific buffering details
    final trackStatus = playerState.trackStatuses[trackId] ?? 'loading';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: trackStatus.contains('error')
              ? Colors.redAccent.withValues(alpha: 0.5)
              : isMuted
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : const Color(0xFF242629),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trackName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Small status pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(trackStatus)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trackStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(trackStatus),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isMuted ? 'MUTED' : '${(trackVol * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isMuted ? Colors.redAccent : const Color(0xFF7F5AF0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              // Mute Button (M)
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isMuted
                        ? Colors.redAccent.withValues(alpha: 0.2)
                        : const Color(0xFF242629),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isMuted ? Colors.redAccent : const Color(0xFF242629),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isMuted ? Colors.redAccent : const Color(0xFF94A1B2),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Volume slider
              Expanded(
                child: Slider(
                  value: isMuted ? 0.0 : trackVol,
                  activeColor: const Color(0xFF7F5AF0),
                  inactiveColor: const Color(0xFF242629),
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
            ],
          ),

          const SizedBox(height: 8),

          // Visual dancing waveforms when playing
          AnimatedWaveform(
              isPlaying:
                  playerState.isPlaying && !isMuted && trackStatus == 'ready',
              volume: trackVol),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'ready') return const Color(0xFF2CB67D);
    if (status == 'buffering') return const Color(0xFFFFB900);
    if (status.contains('error') || status == 'failed') return Colors.redAccent;
    return const Color(0xFF94A1B2);
  }
}

// Waveform visualizer widget
class AnimatedWaveform extends StatefulWidget {
  final bool isPlaying;
  final double volume;
  const AnimatedWaveform(
      {super.key, required this.isPlaying, required this.volume});

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<double> _barHeights = [
    12,
    24,
    8,
    32,
    16,
    20,
    6,
    28,
    14,
    18,
    10,
    30,
    22,
    12,
    16
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    if (widget.isPlaying) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _animController.repeat(reverse: true);
    } else {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Container(
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0E17),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_barHeights.length, (index) {
              // Create dynamic wave bounce
              double multiplier = widget.isPlaying
                  ? (0.3 + (_animController.value * 0.7))
                  : 0.2;

              // Scale according to volume channel settings
              double height = _barHeights[index] * multiplier * widget.volume;

              return Container(
                width: 4,
                height: height.clamp(2.0, 32.0),
                decoration: BoxDecoration(
                  color: widget.isPlaying
                      ? const Color(0xFF7F5AF0).withValues(alpha: 0.8)
                      : const Color(0xFF242629),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: Dashboard & Upload Screen
// -----------------------------------------------------------------------------

class UploadTab extends ConsumerWidget {
  const UploadTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final selectedProject = ref.watch(selectedProjectProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section A: Project Upload Desk
          const CreateProjectCard(),
          const SizedBox(height: 24),

          // Section B: Session Vault
          const Text(
            'STUDIO VAULT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Color(0xFF2CB67D),
            ),
          ),
          const SizedBox(height: 12),

          projectsAsync.when(
            data: (projects) {
              if (projects.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Text(
                        'No project sessions saved. Build a session above!',
                        style: TextStyle(color: Color(0xFF94A1B2)),
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  final isLoaded = selectedProject != null &&
                      selectedProject['id'] == project['id'];
                  final List<dynamic> stems = project['tracks'] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLoaded
                            ? const Color(0xFF7F5AF0)
                            : const Color(0xFF242629),
                        width: isLoaded ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isLoaded
                              ? const Color(0xFF7F5AF0).withValues(alpha: 0.15)
                              : const Color(0xFF242629),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.audio_file_rounded,
                          color: isLoaded
                              ? const Color(0xFF7F5AF0)
                              : Colors.white70,
                        ),
                      ),
                      title: Text(
                        project['title'] ?? 'Untitled Song',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${stems.length} audio stems',
                        style: const TextStyle(
                            color: Color(0xFF94A1B2), fontSize: 12),
                      ),
                      trailing: isLoaded
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7F5AF0)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF7F5AF0), width: 0.5),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A1B2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF242629),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                ref
                                    .read(selectedProjectProvider.notifier)
                                    .state = project;
                                ref
                                    .read(stemVolumesProvider.notifier)
                                    .reset(stems);
                                ref
                                    .read(stemMutesProvider.notifier)
                                    .reset(stems);

                                // Initiate loading sequence on actual just_audio players!
                                ref
                                    .read(multiStemPlayerProvider.notifier)
                                    .loadProject(project);

                                ref.read(currentTabProvider.notifier).state =
                                    0; // Switch to mixer
                              },
                              child: const Text('LOAD'),
                            ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load from repository:\n$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF242629)),
                    onPressed: () =>
                        ref.read(projectsProvider.notifier).loadProjects(),
                    child: const Text('Retry Connection'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget to pick stems and upload a project
class CreateProjectCard extends ConsumerStatefulWidget {
  const CreateProjectCard({super.key});

  @override
  ConsumerState<CreateProjectCard> createState() => _CreateProjectCardState();
}

class _CreateProjectCardState extends ConsumerState<CreateProjectCard> {
  final _titleController = TextEditingController();

  Future<void> _pickStems() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        ref.read(pickedFilesProvider.notifier).state = [
          ...ref.read(pickedFilesProvider),
          ...result.files,
        ];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error choosing audio: $e')),
        );
      }
    }
  }

  Future<void> _submitProject() async {
    final title = _titleController.text.trim();
    final files = ref.read(pickedFilesProvider);

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a session title.')),
      );
      return;
    }

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one audio stem file.')),
      );
      return;
    }

    ref.read(isUploadingProvider.notifier).state = true;

    try {
      final client = ref.read(apiClientProvider);
      final newProj = await client.uploadProject(title, files);

      // Success: Clear fields
      _titleController.clear();
      ref.read(pickedFilesProvider.notifier).state = [];

      // Refresh project list
      await ref.read(projectsProvider.notifier).loadProjects();
      ref.read(selectedProjectProvider.notifier).state = newProj;

      // Auto-configure new stem mixer slots
      final List<dynamic> stems = newProj['tracks'] ?? [];
      ref.read(stemVolumesProvider.notifier).reset(stems);
      ref.read(stemMutesProvider.notifier).reset(stems);

      // Instantly load the uploaded project in the multi-stem players
      ref.read(multiStemPlayerProvider.notifier).loadProject(newProj);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2CB67D),
            content: Text('Session "${newProj['title']}" successfully built!'),
          ),
        );
        // Switch to mixer board
        ref.read(currentTabProvider.notifier).state = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to compile session: $e'),
          ),
        );
      }
    } finally {
      ref.read(isUploadingProvider.notifier).state = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickedFiles = ref.watch(pickedFilesProvider);
    final isUploading = ref.watch(isUploadingProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242629), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMPILE NEW SESSION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7F5AF0),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Project name input
          TextField(
            controller: _titleController,
            enabled: !isUploading,
            decoration: InputDecoration(
              labelText: 'Session / Song Title',
              labelStyle: const TextStyle(color: Color(0xFF94A1B2)),
              hintText: 'e.g., Summer Anthem 2026',
              filled: true,
              fillColor: const Color(0xFF0F0E17),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF242629)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF7F5AF0)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // File select actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_to_photos_rounded),
                  label: const Text('Add Audio Stems'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF7F5AF0)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isUploading ? null : _pickStems,
                ),
              ),
            ],
          ),

          if (pickedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Selected Stems:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0E17),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pickedFiles.length,
                itemBuilder: (context, index) {
                  final file = pickedFiles[index];
                  // Size in MB
                  final sizeMB = (file.size / (1024 * 1024)).toStringAsFixed(2);

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.music_note_rounded,
                        color: Color(0xFF7F5AF0)),
                    title: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('$sizeMB MB'),
                    trailing: IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: Colors.redAccent, size: 18),
                      onPressed: () {
                        final current = ref.read(pickedFilesProvider);
                        final updated = List<PlatformFile>.from(current)
                          ..removeAt(index);
                        ref.read(pickedFilesProvider.notifier).state = updated;
                      },
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(isUploading
                  ? 'Compiling Session...'
                  : 'Build Audio Lab Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F5AF0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isUploading ? null : _submitProject,
            ),
          ),
        ],
      ),
    );
  }
}
