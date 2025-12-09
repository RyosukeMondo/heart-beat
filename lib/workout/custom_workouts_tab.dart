import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'workout_config.dart';
import 'workout_settings.dart';
import 'config_card.dart';
import 'config_dialog.dart';

class CustomWorkoutsTab extends StatefulWidget {
  const CustomWorkoutsTab({super.key});

  @override
  State<CustomWorkoutsTab> createState() => _CustomWorkoutsTabState();
}

class _CustomWorkoutsTabState extends State<CustomWorkoutsTab> {
  @override
  Widget build(BuildContext context) {
    final w = context.watch<WorkoutSettings>();
    final customConfigs = w.customConfigs;

    return Column(
      children: [
        if (w.isUsingCustomConfig)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Currently using: ${w.selectedCustomConfig!.name}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => w.clearCustomWorkoutSelection(),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Default Configurations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...w.defaultConfigs.map((config) => ConfigCard(
                    config: config,
                    isDefault: true,
                    onEdit: () {},
                    onDelete: () {},
                  )),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Custom Configurations',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showCreateConfigDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (customConfigs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.fitness_center,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No custom workout configurations yet',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Create" to add a custom workout profile',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...customConfigs.map(
                  (config) => ConfigCard(
                    config: config,
                    isDefault: false,
                    onEdit: () => _showEditConfigDialog(config),
                    onDelete: () => _showDeleteConfigDialog(config),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => const ConfigDialog(
        title: 'Create Custom Workout',
        isEditing: false,
        initialDuration: '30',
      ),
    );
  }

  void _showEditConfigDialog(WorkoutConfig config) {
    showDialog(
      context: context,
      builder: (context) => ConfigDialog(
        title: 'Edit Custom Workout',
        isEditing: true,
        editingConfig: config,
        initialName: config.name,
        initialDescription: config.description,
        initialMinHr: config.minHeartRate.toString(),
        initialMaxHr: config.maxHeartRate.toString(),
        initialDuration: config.durationInMinutes.toString(),
        initialIntensity: config.intensityLevel,
        initialColor: Color(
            int.parse(config.colorCode.substring(1), radix: 16) + 0xFF000000),
      ),
    );
  }

  void _showDeleteConfigDialog(WorkoutConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout Configuration'),
        content: Text(
          'Are you sure you want to delete "${config.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final workoutSettings = context.read<WorkoutSettings>();
              final success =
                  await workoutSettings.deleteWorkoutConfig(config.id);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Workout configuration deleted'
                          : 'Failed to delete workout configuration',
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
