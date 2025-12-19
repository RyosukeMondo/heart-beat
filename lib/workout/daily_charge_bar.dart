import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coaching_controller.dart';
import 'coaching_state.dart';

class DailyChargeBar extends ConsumerWidget {
  const DailyChargeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coachingControllerProvider);

    // Calculate progress based on daily minutes
    final double progress = state.targetMinutes > 0
        ? (state.dailyMinutes / state.targetMinutes).clamp(0.0, 1.0)
        : 0.0;

    final theme = Theme.of(context);
    final isPaused = state.status == SessionStatus.paused;
    final isReconnecting = state.reconnecting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY CHARGE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '今日の目標達成度',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${state.dailyMinutes}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    ' / ${state.targetMinutes} mins',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Background track
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              // Progress fill with animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: progress),
                builder: (context, value, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        width: constraints.maxWidth * value,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isReconnecting || isPaused
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            if (!isReconnecting && !isPaused && value > 0)
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              // Status text overlay
              Positioned.fill(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isReconnecting
                        ? const Text(
                            '再接続中...',
                            key: ValueKey('reconnecting'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          )
                        : isPaused
                            ? const Text(
                                '一時停止中',
                                key: ValueKey('paused'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
              ),
              // Gap indicator
              if (state.hasGaps)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          if (state.hasGaps)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                '※接続中断によるデータの欠落があります',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.amber.shade900,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
