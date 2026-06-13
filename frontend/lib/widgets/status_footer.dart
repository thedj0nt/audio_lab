import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';

class StatusFooter extends ConsumerWidget {
  const StatusFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 600;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ECHO ENGINE v2.4.0',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              if (isWide) ...[
                const SizedBox(width: 12),
                Text(
                  'STABLE CONNECTION',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: colors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
          if (isWide)
            Text(
              'CPU: 12%  DISK: 2%  MEM: 1.4GB',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: colors.textSecondary,
              ),
            )
          else
            Text(
              'ONLINE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}
