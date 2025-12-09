import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'profile.dart';
import 'workout_settings.dart';
import 'workout_config.dart';
import 'profile_form.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
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

    return ProfileForm(
      ageCtl: _ageCtl,
      restCtl: _restCtl,
      gender: _gender,
      selected: _selected,
      isUsingCustomConfig: w.isUsingCustomConfig,
      customConfigName: w.selectedCustomConfig?.name,
      profile: profile,
      zones: zones,
      onGenderChanged: (v) => setState(() => _gender = v ?? Gender.other),
      onWorkoutSelected: (t) => setState(() {
        _selected = t;
        context.read<WorkoutSettings>().clearCustomWorkoutSelection();
      }),
      onReset: () {
        final ww = context.read<WorkoutSettings>();
        setState(() {
          _ageCtl.text = ww.age.toString();
          _restCtl.text = ww.restingHr?.toString() ?? '';
          _gender = ww.gender;
          _selected = ww.selected;
        });
      },
      onSave: () async {
        final age = int.tryParse(_ageCtl.text) ?? w.age;
        final rest = int.tryParse(_restCtl.text);
        await w.updateProfile(age: age, gender: _gender, restingHr: rest);
        if (!w.isUsingCustomConfig) {
          await w.selectWorkout(_selected);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully!')),
          );
        }
      },
    );
  }
}
