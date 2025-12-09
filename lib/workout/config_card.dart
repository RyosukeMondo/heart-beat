import 'package:flutter/material.dart';
import 'workout_config.dart';
import 'workout_settings.dart';
import 'package:provider/provider.dart';

class ConfigCard extends StatelessWidget {
  final WorkoutConfig config;
  final bool isDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ConfigCard({
    super.key,
    required this.config,
    required this.isDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WorkoutSettings>();
    final isSelected =
        w.isUsingCustomConfig && w.selectedCustomConfig?.id == config.id;

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (!isDefault) {
            w.selectCustomWorkout(config.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(
                          int.parse(config.colorCode.substring(1), radix: 16) +
                              0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      config.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary),
                  if (!isDefault) ...[
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, size: 18),
                      tooltip: 'Delete',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                config.description,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.red[400]),
                  const SizedBox(width: 4),
                  Text(config.targetZoneText),
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 16, color: Colors.blue[400]),
                  const SizedBox(width: 4),
                  Text(config.durationText),
                  const SizedBox(width: 16),
                  Icon(Icons.whatshot, size: 16, color: Colors.orange[400]),
                  const SizedBox(width: 4),
                  Text('${config.intensityLevel}/5'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
