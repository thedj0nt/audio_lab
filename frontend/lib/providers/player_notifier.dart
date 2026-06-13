// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../core/api_client.dart';
import 'audio_providers.dart';

class MultiStemPlayerState {
  final bool isPlaying;
  final bool isLoading;
  final bool isReady;
  final double progress; // 0.0 to 1.0
  final Duration currentPosition;
  final Duration totalDuration;
  final String statusMessage;
  final Map<int, String> trackStatuses;

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
      statusMessage: 'Select a project to load mixing workspace',
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
  Timer? _pollingTimer;

  MultiStemPlayerNotifier(this._ref) : super(MultiStemPlayerState.initial());

  /// Polls the project status from backend until it is 'Completed' or 'Failed'
  void startPollingStatus(int projectId) {
    _pollingTimer?.cancel();
    print(
        '[CONSOLE] 📡 Starting active status polling for Project ID: $projectId');

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final client = _ref.read(apiClientProvider);
        final projects = await client.fetchProjects();

        final updatedProject = projects.firstWhere(
          (p) => p['id'] == projectId,
          orElse: () => null,
        );

        if (updatedProject != null) {
          final String newStatus = updatedProject['status'] ?? 'Pending';
          print('[CONSOLE] 🔍 Polling Project $projectId status: $newStatus');

          if (newStatus == 'Completed') {
            timer.cancel();
            print('[CONSOLE] 🎉 separation Completed! Loading stems.');

            // Update selected project structure
            _ref.read(selectedProjectProvider.notifier).state = updatedProject;

            // Load newly created audio track stems into players
            await loadProject(updatedProject);

            // Refresh dashboard list
            _ref.read(projectsProvider.notifier).loadProjects();
          } else if (newStatus == 'Failed') {
            timer.cancel();
            print('[CONSOLE] ❌ Project separation failed on Celery worker.');

            _ref.read(selectedProjectProvider.notifier).state = updatedProject;
            state = state.copyWith(
              isReady: false,
              isLoading: false,
              statusMessage: 'AI Separation job failed on backend.',
            );
            _ref.read(projectsProvider.notifier).loadProjects();
          } else {
            // Processing/Pending
            state = state.copyWith(
              statusMessage: 'AI Separation in progress... ($newStatus)',
            );
          }
        }
      } catch (e) {
        print('[CONSOLE] ⚠️ Polling connection error: $e');
      }
    });
  }

  /// Sets up a player instance for each track stem and initiates HTTP 206 buffering
  Future<void> loadProject(Map<String, dynamic> project) async {
    final int projectId = project['id'];
    final String projectStatus = project['status'] ?? 'Pending';

    // Clear any active playing instances and status timers
    await _cleanup();
    _pollingTimer?.cancel();

    final List<dynamic> allTracks = project['tracks'] ?? [];
    _ref.read(stemVolumesProvider.notifier).reset(allTracks);
    _ref.read(stemMutesProvider.notifier).reset(allTracks);
    _ref.read(stemSolosProvider.notifier).reset(allTracks);

    Duration initialDuration = Duration.zero;
    final int? backendDurationSeconds = project['duration'];
    if (backendDurationSeconds != null && backendDurationSeconds > 0) {
      initialDuration = Duration(seconds: backendDurationSeconds);
    }

    state = state.copyWith(
      isLoading: true,
      isReady: false,
      isPlaying: false,
      statusMessage: 'Loading audio stems...',
      trackStatuses: {},
      totalDuration: initialDuration,
      progress: 0.0,
      currentPosition: Duration.zero,
    );

    // If the project is still processing, enter polling loop and return
    if (projectStatus == 'Processing' || projectStatus == 'Pending') {
      state = state.copyWith(
        statusMessage:
            'AI separation task is running on worker ($projectStatus)...',
      );
      startPollingStatus(projectId);
      return;
    }

    if (projectStatus == 'Failed') {
      state = state.copyWith(
        isLoading: false,
        isReady: false,
        statusMessage: 'Failed: AI Separation failed on backend.',
      );
      return;
    }

    final List<dynamic> tracks = projectStatus == 'Completed'
        ? (allTracks.isNotEmpty ? allTracks.sublist(1) : <dynamic>[])
        : allTracks;

    if (tracks.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        statusMessage:
            'No track stems found (Wait for AI processing to finish).',
      );
      return;
    }

    // Set initial loading states for track rows
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

          print(
              '[AudioPlayer Listener - Track: "$trackName" (ID: $trackId)] state.playing: $playing, state.processingState: $processingState');

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

            // Sync current mixer controls using the solo-aware logic
            final double actualVol = _calculateTrackVolume(trackId);
            await player.setVolume(actualVol);
            print(
                '[CONSOLE] 🔊 Stem "$trackName" volume initialized to $actualVol');
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

      // Calculate overall max duration returned from media assets, or fallback to backend metadata duration!
      Duration totalDur = Duration.zero;
      final int? backendDurationSeconds = project['duration'];
      if (backendDurationSeconds != null && backendDurationSeconds > 0) {
        totalDur = Duration(seconds: backendDurationSeconds);
      }

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
    final bool wasPlaying = state.isPlaying;
    if (wasPlaying) {
      await Future.wait(_players.values.map((p) => p.pause()));
    }
    final totalMs = state.totalDuration.inMilliseconds;
    final targetMs = (progress * totalMs).toInt();
    final targetDuration = Duration(milliseconds: targetMs);

    print('[CONSOLE] 🔍 Seeking all stems sequentially to: $targetDuration');
    for (var player in _players.values) {
      await player.seek(targetDuration);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    state = state.copyWith(
      progress: progress,
      currentPosition: targetDuration,
    );

    if (wasPlaying) {
      await Future.wait(_players.values.map((p) => p.play()));
    }
  }

  /// Computes the actual playback volume of a track stem taking into account
  /// individual volume slider, mute state, solo states, and master volume.
  double _calculateTrackVolume(int trackId) {
    final volumes = _ref.read(stemVolumesProvider);
    final mutes = _ref.read(stemMutesProvider);
    final solos = _ref.read(stemSolosProvider);
    final masterVol = _ref.read(masterVolumeProvider);

    final trackVol = volumes[trackId] ?? 0.75;
    final isMuted = mutes[trackId] ?? false;
    final isSoloed = solos[trackId] ?? false;

    // Check if any track in the current project is soloed
    final hasAnySolo = solos.values.any((s) => s == true);

    if (isMuted) {
      return 0.0;
    }

    if (hasAnySolo) {
      // If there is any solo, only play if this track is soloed
      return isSoloed ? trackVol * masterVol : 0.0;
    } else {
      // Otherwise, play normally
      return trackVol * masterVol;
    }
  }

  /// Recalculates and applies volumes to all active players.
  /// This must be called when master volume, individual mutes, or solo states change.
  void updateAllTrackVolumes() {
    _players.forEach((trackId, player) {
      player.setVolume(_calculateTrackVolume(trackId));
    });
  }

  /// Sets volume dynamically on individual track channels
  void setTrackVolume(int trackId, double volume) {
    final player = _players[trackId];
    if (player != null) {
      player.setVolume(_calculateTrackVolume(trackId));
    }
  }

  /// Mutes and unmutes players cleanly without losing slider state settings
  void setTrackMute(int trackId, bool isMuted) {
    updateAllTrackVolumes();
  }

  /// Modifies master slider mix gain across all unmuted tracks
  void updateMasterVolume(double masterVolume) {
    updateAllTrackVolumes();
  }

  /// Disposes active player objects
  Future<void> unload() async {
    print('[CONSOLE] 📂 Closing project stem slots.');
    await _cleanup();
    _pollingTimer?.cancel();
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
    _pollingTimer?.cancel();
    super.dispose();
  }
}
