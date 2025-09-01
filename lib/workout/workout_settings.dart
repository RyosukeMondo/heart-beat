import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../player/settings.dart';
import 'profile.dart';

enum WorkoutType { recovery, fatBurn, endurance, tempo, hiit }

class WorkoutSettings extends ChangeNotifier {
  // persisted
  int age = 35;
  Gender gender = Gender.other;
  int? restingHr;
  WorkoutType selected = WorkoutType.fatBurn;

  static const _kAge = 'workout.age';
  static const _kGender = 'workout.gender';
  static const _kRest = 'workout.restingHr';
  static const _kSelected = 'workout.selected';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    age = p.getInt(_kAge) ?? age;
    final g = p.getString(_kGender);
    if (g != null) {
      gender = Gender.values.firstWhere(
        (e) => e.name == g,
        orElse: () => Gender.other,
      );
    }
    restingHr = p.getInt(_kRest);
    final s = p.getString(_kSelected);
    if (s != null) {
      selected = WorkoutType.values.firstWhere(
        (e) => e.name == s,
        orElse: () => selected,
      );
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kAge, age);
    await p.setString(_kGender, gender.name);
    if (restingHr == null) {
      await p.remove(_kRest);
    } else {
      await p.setInt(_kRest, restingHr!.clamp(30, 120));
    }
    await p.setString(_kSelected, selected.name);
  }

  WorkoutProfile get profile => WorkoutProfile(age: age, gender: gender, restingHr: restingHr);

  Future<void> updateProfile({int? age, Gender? gender, int? restingHr}) async {
    if (age != null) this.age = age.clamp(5, 100);
    if (gender != null) this.gender = gender;
    this.restingHr = restingHr; // allow null
    await _save();
    notifyListeners();
  }

  Future<void> selectWorkout(WorkoutType t) async {
    selected = t;
    await _save();
    notifyListeners();
  }

  // Compute target range (lower, upper) bpm from zones
  (int lower, int upper) targetRange() {
    final prof = profile;
    final byK = prof.zonesByKarvonen();
    final zones = byK ?? prof.zonesByMax();
    // Map workout to zone(s)
    switch (selected) {
      case WorkoutType.recovery:
        final z1 = zones[1]!;
        return (z1.$1, z1.$2);
      case WorkoutType.fatBurn:
        final z2 = zones[2]!;
        return (z2.$1, z2.$2);
      case WorkoutType.endurance:
        final z2 = zones[2]!;
        final z3 = zones[3]!;
        return (z2.$1, z3.$2); // span Z2-Z3
      case WorkoutType.tempo:
        final z4 = zones[4]!;
        return (z4.$1, z4.$2);
      case WorkoutType.hiit:
        final z5 = zones[5]!;
        return (z5.$1, z5.$2);
    }
  }

  // Apply current target range to PlayerSettings thresholds.
  // Strategy: pauseBelow = lower-5, normalHigh = lower, linearHigh = upper
  Future<void> applyToPlayer(PlayerSettings s) async {
    final (lo, hi) = targetRange();
    final pauseBelow = (lo - 5).clamp(40, lo);
    await s.update(
      pauseBelow: pauseBelow,
      normalHigh: lo,
      linearHigh: hi,
    );
  }
}
