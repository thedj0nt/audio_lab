import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_providers.dart';

class DAWWaveform extends ConsumerStatefulWidget {
  final double progress;
  final bool isPlaying;

  const DAWWaveform({
    super.key,
    required this.progress,
    required this.isPlaying,
  });

  @override
  ConsumerState<DAWWaveform> createState() => _DAWWaveformState();
}

class _DAWWaveformState extends ConsumerState<DAWWaveform> {
  double? _dragProgress;

  @override
  Widget build(BuildContext context) {
    // A simulated array of waveform bar heights (0.0 to 1.0)
    final List<double> barHeights = [
      0.2,
      0.3,
      0.5,
      0.7,
      0.4,
      0.6,
      0.8,
      0.9,
      0.5,
      0.3,
      0.6,
      0.8,
      0.7,
      0.4,
      0.5,
      0.3,
      0.6,
      0.8,
      0.9,
      0.7,
      0.5,
      0.3,
      0.2,
      0.4,
      0.6,
      0.8,
      0.7,
      0.5,
      0.4,
      0.6,
      0.8,
      0.9,
      0.7,
      0.6,
      0.5,
      0.3,
      0.4,
      0.6,
      0.8,
      0.7,
      0.5,
      0.3,
      0.4,
      0.6,
      0.8,
      0.9,
      0.7,
      0.5,
      0.3,
      0.2,
    ];

    final double activeProgress = _dragProgress ?? widget.progress;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A0A0C)
            : const Color(0xFFE5E5EA).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E22)
              : const Color(0xFFE5E5EA),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final int barCount = barHeights.length;
          final double barWidth = (width / barCount) - 3;

          return GestureDetector(
            onTapDown: (details) {
              final double pct =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
              ref.read(multiStemPlayerProvider.notifier).seek(pct);
            },
            onHorizontalDragStart: (details) {
              final double pct =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() {
                _dragProgress = pct;
              });
            },
            onHorizontalDragUpdate: (details) {
              final double pct =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() {
                _dragProgress = pct;
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragProgress != null) {
                ref
                    .read(multiStemPlayerProvider.notifier)
                    .seek(_dragProgress!)
                    .then((_) {
                  if (mounted) {
                    setState(() {
                      _dragProgress = null;
                    });
                  }
                });
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(barCount, (index) {
                final double hFactor = barHeights[index];
                final double barHeight = height * hFactor;
                final double threshold = index / barCount;
                final bool isPassed = activeProgress >= threshold;

                return Container(
                  width: barWidth > 1 ? barWidth : 1,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: isPassed
                        ? const Color(0xFFFF3E3E)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E1E22)
                            : const Color(0xFFD1D1D6)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
