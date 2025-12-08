import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coaching_controller.dart';
import 'coaching_state.dart';

class ZoneMeter extends ConsumerWidget {
  const ZoneMeter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coachingControllerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCueDisplay(context, state),
          const SizedBox(height: 20),
          _buildBpmDisplay(context, state),
        ],
      ),
    );
  }

  Widget _buildCueDisplay(BuildContext context, CoachingState state) {
    String text;
    Color color;
    IconData icon;

    switch (state.cue) {
      case ZoneCue.up:
        text = 'UP';
        color = Colors.blue;
        icon = Icons.arrow_upward;
        break;
      case ZoneCue.keep:
        text = 'KEEP';
        // Green to Orange gradient is hard for a single color, let's use Green for now
        // or check where in the range we are.
        // Spec says "green->orange gradient".
        color = Colors.green;
        icon = Icons.import_export; // Or some double arrow
        break;
      case ZoneCue.down:
        text = 'DOWN';
        color = Colors.red;
        icon = Icons.arrow_downward;
        break;
    }

    if (state.currentBpm == 0) {
      text = '--';
      color = Colors.grey;
      icon = Icons.horizontal_rule;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBpmDisplay(BuildContext context, CoachingState state) {
    return Column(
      children: [
        Text(
          '${state.currentBpm}',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'BPM',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Target: ${state.targetLowerBpm} - ${state.targetUpperBpm}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
