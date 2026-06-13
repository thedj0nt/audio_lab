import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core/api_client.dart';
import 'projects_notifier.dart';
import 'player_notifier.dart';

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// Projects loading state
final projectsProvider =
    StateNotifierProvider<ProjectsNotifier, AsyncValue<List<dynamic>>>((ref) {
  return ProjectsNotifier(ref.watch(apiClientProvider));
});

// Currently selected project
final selectedProjectProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

// Screen selector (0: Library, 1: Workstation Mixer, 2: Settings)
final currentTabProvider = StateProvider<int>((ref) => 0);

// Master Volume state
final masterVolumeProvider = StateProvider<double>((ref) => 0.8);

// Upload form state
final pickedFilesProvider = StateProvider<List<PlatformFile>>((ref) => []);
final isUploadingProvider = StateProvider<bool>((ref) => false);

// Interactive Library States
final searchQueryProvider = StateProvider<String>((ref) => '');
final libraryViewModeProvider = StateProvider<String>((ref) => 'list'); // 'list' or 'grid'
final statusFilterProvider = StateProvider<String>((ref) => 'ALL'); // 'ALL', 'MASTERED', 'IN PROGRESS', 'FAILED'
final modelFilterProvider = StateProvider<String>((ref) => 'ALL'); // 'ALL', '4-STEM', '6-STEM'

// Track Stem Volumes controller (Map: trackId -> volume)
class StemVolumesController extends StateNotifier<Map<int, double>> {
  StemVolumesController() : super({});

  void setVolume(int trackId, double volume) {
    state = {...state, trackId: volume};
  }

  void reset(List<dynamic> tracks) {
    final Map<int, double> initial = {};
    for (var track in tracks) {
      initial[track['id'] as int] = 0.75;
    }
    state = initial;
  }
}

final stemVolumesProvider =
    StateNotifierProvider<StemVolumesController, Map<int, double>>((ref) {
  return StemVolumesController();
});

// Track Stem Mutes controller (Map: trackId -> isMuted)
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

// Track Stem Solos controller (Map: trackId -> isSoloed)
class StemSolosController extends StateNotifier<Map<int, bool>> {
  StemSolosController() : super({});

  void toggleSolo(int trackId) {
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

final stemSolosProvider =
    StateNotifierProvider<StemSolosController, Map<int, bool>>((ref) {
  return StemSolosController();
});

// Synchronized Audio Player Provider
final multiStemPlayerProvider =
    StateNotifierProvider<MultiStemPlayerNotifier, MultiStemPlayerState>((ref) {
  return MultiStemPlayerNotifier(ref);
});
