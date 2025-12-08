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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAILY CHARGE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${state.dailyMinutes} / ${state.targetMinutes} mins',
                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              // Background track
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Progress fill
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: constraints.maxWidth * progress,
                    height: 24,
                    decoration: BoxDecoration(
                      color: (state.status == SessionStatus.paused) || state.reconnecting
                          ? Colors.grey
                          : Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                },
              ),
              // Reconnecting / Paused overlay
              if (state.reconnecting)
                Positioned.fill(
                  child: Center(
                    child: Text(
                      'RECONNECTING...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                )
              else if (state.status == SessionStatus.paused)
                 Positioned.fill(
                  child: Center(
                    child: Text(
                      'PAUSED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold
                      ),
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
