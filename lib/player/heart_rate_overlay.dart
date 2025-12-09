import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;

import '../workout/workout_settings.dart';

class HeartRateOverlay extends StatelessWidget {
  final int? currentBpm;
  final double? ema;
  final bool showOverlay;

  const HeartRateOverlay({
    super.key,
    required this.currentBpm,
    required this.ema,
    required this.showOverlay,
  });

  @override
  Widget build(BuildContext context) {
    if (!showOverlay) return const SizedBox.shrink();

    final workoutSettings = p.Provider.of<WorkoutSettings>(context);
    final (lower, upper) = workoutSettings.targetRange();
    final color = _getHeartRateColor(lower, upper);

    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentBpm ?? '--'} BPM',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (ema != null) ...[
              const SizedBox(height: 4),
              Text(
                'EMA: ${ema!.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Target: $lower-$upper',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            if (workoutSettings.isUsingCustomConfig) ...[
              const SizedBox(height: 4),
              Text(
                workoutSettings.selectedCustomConfig!.name,
                style: TextStyle(
                  color: Color(int.parse(
                        workoutSettings.selectedCustomConfig!.colorCode
                            .substring(1),
                        radix: 16,
                      ) +
                      0xFF000000),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getHeartRateColor(int lower, int upper) {
    if (currentBpm == null) return Colors.grey;

    if (currentBpm! < lower) {
      return Colors.blue; // Below target zone
    } else if (currentBpm! > upper) {
      return Colors.red; // Above target zone
    } else {
      return Colors.green; // In target zone
    }
  }
}
