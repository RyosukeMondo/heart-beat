import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'player/settings.dart';
import 'workout/workout_settings.dart';
import 'auth/auth_settings.dart';

final playerSettingsProvider = ChangeNotifierProvider<PlayerSettings>((ref) {
  final settings = PlayerSettings();
  settings.load();
  return settings;
});

final workoutSettingsProvider = ChangeNotifierProvider<WorkoutSettings>((ref) {
  final settings = WorkoutSettings();
  settings.load();
  return settings;
});

final authSettingsProvider = ChangeNotifierProvider<AuthSettings>((ref) {
  return AuthSettings();
});
