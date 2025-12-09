import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;
import '../workout/workout_settings.dart';
import 'settings.dart';

class PlayerControls extends StatelessWidget {
  final TextEditingController urlController;
  final VoidCallback onLoad;
  final VoidCallback onReport;
  final int? currentBpm;
  final double? ema;
  final double? playbackRate;
  final bool isReady;
  final int? ytState;
  final int? ytError;
  final bool debugLog;
  final ValueChanged<bool> onDebugLogChanged;
  final bool showOverlay;
  final ValueChanged<bool> onShowOverlayChanged;
  final PlayerSettings playerSettings;

  const PlayerControls({
    super.key,
    required this.urlController,
    required this.onLoad,
    required this.onReport,
    this.currentBpm,
    this.ema,
    this.playbackRate,
    required this.isReady,
    this.ytState,
    this.ytError,
    required this.debugLog,
    required this.onDebugLogChanged,
    required this.showOverlay,
    required this.onShowOverlayChanged,
    required this.playerSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'YouTube URL',
                    hintText:
                        'https://www.youtube.com/watch?v=... or youtu.be/...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Load'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onReport,
                child: const Text('Report'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BPM: ${currentBpm ?? '--'}'),
              Text('EMA: ${ema?.toStringAsFixed(1) ?? '--'}'),
              Text(
                'Rate: ${playbackRate?.toStringAsFixed(2) ?? '--'}x',
              ),
              Text('Ready: ${isReady ? 'Y' : 'N'}'),
              if (ytState != null) Text('State: $ytState'),
            ],
          ),
          if (ytError == 101 || ytError == 150)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'This video cannot be embedded (error $ytError). Try a different URL.',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Debug log'),
            value: debugLog,
            onChanged: onDebugLogChanged,
          ),
          p.Consumer<WorkoutSettings>(
            builder: (context, workout, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Workout Configuration')),
                      Switch.adaptive(
                        value: showOverlay,
                        onChanged: onShowOverlayChanged,
                      ),
                      const Text('Overlay'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildWorkoutSelection(context, workout),
                  const SizedBox(height: 8),
                  Text(
                    'Applied thresholds: pause<${playerSettings.pauseBelow}  1.0x≤${playerSettings.normalHigh}  →2.0x@${playerSettings.linearHigh}',
                    style: const TextStyle(fontSize: 11),
                  )
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          const Text('注: 動画はユーザーが再生を開始してください（自動再生制限）。'),
        ],
      ),
    );
  }

  Widget _buildWorkoutSelection(BuildContext context, WorkoutSettings workout) {
    if (workout.isUsingCustomConfig) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Color(int.parse(
                        workout.selectedCustomConfig!.colorCode.substring(1),
                        radix: 16,
                      ) +
                      0xFF000000),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${workout.selectedCustomConfig!.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${workout.selectedCustomConfig!.targetZoneText} • ${workout.selectedCustomConfig!.durationText}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => workout.clearCustomWorkoutSelection(),
                icon: const Icon(Icons.clear),
                tooltip: 'Clear custom workout',
              ),
            ],
          ),
        ),
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: WorkoutType.values.map((t) {
          final selected = workout.selected == t;
          return ChoiceChip(
            label: Text(_labelFor(t)),
            selected: selected,
            onSelected: (_) async {
              await workout.selectWorkout(t);
              await workout.applyToPlayer(playerSettings);
            },
          );
        }).toList(),
      );
    }
  }

  String _labelFor(WorkoutType t) {
    switch (t) {
      case WorkoutType.recovery:
        return 'Recovery (Z1)';
      case WorkoutType.fatBurn:
        return 'Fat Burn (Z2)';
      case WorkoutType.endurance:
        return 'Endurance (Z2-3)';
      case WorkoutType.tempo:
        return 'Tempo (Z4)';
      case WorkoutType.hiit:
        return 'HIIT (Z5)';
    }
  }
}
