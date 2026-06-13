import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

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
