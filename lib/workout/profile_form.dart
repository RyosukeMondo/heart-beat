import 'package:flutter/material.dart';
import 'workout_settings.dart';
import 'profile.dart';

class ProfileForm extends StatelessWidget {
  final TextEditingController ageCtl;
  final TextEditingController restCtl;
  final Gender gender;
  final WorkoutType selected;
  final bool isUsingCustomConfig;
  final String? customConfigName;
  final WorkoutProfile profile;
  final Map<int, (int, int)> zones;
  final ValueChanged<Gender?> onGenderChanged;
  final ValueChanged<WorkoutType> onWorkoutSelected;
  final int dailyTargetMinutes;
  final ValueChanged<int> onTargetMinutesChanged;
  final VoidCallback onReset;
  final VoidCallback onSave;

  const ProfileForm({
    super.key,
    required this.ageCtl,
    required this.restCtl,
    required this.gender,
    required this.selected,
    required this.isUsingCustomConfig,
    required this.customConfigName,
    required this.profile,
    required this.zones,
    required this.dailyTargetMinutes,
    required this.onGenderChanged,
    required this.onWorkoutSelected,
    required this.onTargetMinutesChanged,
    required this.onReset,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ageCtl,
                decoration: const InputDecoration(labelText: 'Age (years)')
                    .copyWith(prefixIcon: const Icon(Icons.cake)),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<Gender>(
                value: gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: Gender.values
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                    .toList(),
                onChanged: onGenderChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: restCtl,
          decoration: const InputDecoration(
            labelText: 'Resting HR (optional, bpm)',
            hintText: 'e.g., 60',
            prefixIcon: Icon(Icons.favorite_outline),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        const Text('Daily Target (minutes)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Slider(
          value: dailyTargetMinutes.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          label: '$dailyTargetMinutes mins',
          onChanged: (v) => onTargetMinutesChanged(v.round()),
        ),
        Center(child: Text('$dailyTargetMinutes minutes', style: const TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        const Text('Default Workout Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WorkoutType.values.map((t) {
            final isSelected = selected == t && !isUsingCustomConfig;
            return ChoiceChip(
              label: Text(_labelFor(t)),
              selected: isSelected,
              onSelected: (_) => onWorkoutSelected(t),
            );
          }).toList(),
        ),
        if (isUsingCustomConfig && customConfigName != null) ...[
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.fitness_center,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Custom workout "$customConfigName" is currently selected',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Current Target Zone (bpm)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // ... Further breakdown possible
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reset to Current'),
                onPressed: onReset,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Profile'),
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ],
    );
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
