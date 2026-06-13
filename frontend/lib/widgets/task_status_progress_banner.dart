import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_providers.dart';
import '../core/theme.dart';

class TaskStatusProgressBanner extends ConsumerWidget {
  const TaskStatusProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProject = ref.watch(selectedProjectProvider);
    final playerState = ref.watch(multiStemPlayerProvider);
    final colors = ref.watch(themeColorsProvider);

    String statusText = 'LOADING AUDIO STEMS...';
    bool showProgress = true;

    if (selectedProject != null) {
      final status = selectedProject['status'] ?? 'Pending';
      if (status == 'Processing') {
        statusText = 'DEMUCS AI SEPARATION IN PROGRESS...';
      } else if (status == 'Pending') {
        statusText = 'QUEUED IN CELERY PIPELINE...';
      } else if (status == 'Failed') {
        statusText = 'AI SEPARATION FAILED.';
        showProgress = false;
      }
    }

    if (playerState.isLoading) {
      statusText = 'BUFFERING AUDIO CHANNELS...';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.accent, width: 1),
      ),
      child: Row(
        children: [
          if (showProgress)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
          if (showProgress) const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: colors.accent,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
