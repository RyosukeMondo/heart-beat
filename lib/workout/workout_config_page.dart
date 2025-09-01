import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'profile.dart';
import 'workout_settings.dart';

class WorkoutConfigPage extends StatefulWidget {
  const WorkoutConfigPage({super.key});

  @override
  State<WorkoutConfigPage> createState() => _WorkoutConfigPageState();
}

class _WorkoutConfigPageState extends State<WorkoutConfigPage> {
  final _ageCtl = TextEditingController();
  final _restCtl = TextEditingController();
  Gender _gender = Gender.other;
  WorkoutType _selected = WorkoutType.fatBurn;

  @override
  void initState() {
    super.initState();
    final w = context.read<WorkoutSettings>();
    _ageCtl.text = w.age.toString();
    _restCtl.text = w.restingHr?.toString() ?? '';
    _gender = w.gender;
    _selected = w.selected;
  }

  @override
  void dispose() {
    _ageCtl.dispose();
    _restCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WorkoutSettings>();
    final profile = WorkoutProfile(
      age: int.tryParse(_ageCtl.text) ?? w.age,
      gender: _gender,
      restingHr: int.tryParse(_restCtl.text),
    );
    final zones = profile.zonesByKarvonen() ?? profile.zonesByMax();

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Config')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageCtl,
                  decoration: const InputDecoration(labelText: 'Age (years)')
                      .copyWith(prefixIcon: const Icon(Icons.cake)),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<Gender>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: Gender.values
                      .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _gender = v ?? Gender.other),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _restCtl,
            decoration: const InputDecoration(
              labelText: 'Resting HR (optional, bpm)',
              hintText: 'e.g., 60',
              prefixIcon: Icon(Icons.favorite_outline),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          const Text('Default Workout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WorkoutType.values.map((t) {
              final selected = _selected == t;
              return ChoiceChip(
                label: Text(_labelFor(t)),
                selected: selected,
                onSelected: (_) => setState(() => _selected = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Zones Preview (bpm)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Max HR ≈ ${profile.effectiveMaxHr()} bpm'),
                  const SizedBox(height: 8),
                  ...[1, 2, 3, 4, 5].map((z) {
                    final rng = zones[z]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('Z$z: ${rng.$1} - ${rng.$2} bpm'),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset to Current'),
                  onPressed: () {
                    final ww = context.read<WorkoutSettings>();
                    setState(() {
                      _ageCtl.text = ww.age.toString();
                      _restCtl.text = ww.restingHr?.toString() ?? '';
                      _gender = ww.gender;
                      _selected = ww.selected;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: () async {
                    final age = int.tryParse(_ageCtl.text) ?? w.age;
                    final rest = int.tryParse(_restCtl.text);
                    await w.updateProfile(age: age, gender: _gender, restingHr: rest);
                    await w.selectWorkout(_selected);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          )
        ],
      ),
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
