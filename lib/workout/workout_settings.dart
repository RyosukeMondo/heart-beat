import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../player/settings.dart';
import 'profile.dart';
import 'workout_config.dart';

enum WorkoutType { recovery, fatBurn, endurance, tempo, hiit }

class WorkoutSettings extends ChangeNotifier {
  // persisted
  int age = 35;
  Gender gender = Gender.other;
  int? restingHr;
  WorkoutType selected = WorkoutType.fatBurn;
  
  // Custom workout configurations
  List<WorkoutConfig> _customConfigs = [];
  String? _selectedCustomConfigId;

  static const _kAge = 'workout.age';
  static const _kGender = 'workout.gender';
  static const _kRest = 'workout.restingHr';
  static const _kSelected = 'workout.selected';
  static const _kCustomConfigs = 'workout.customConfigs';
  static const _kSelectedCustom = 'workout.selectedCustom';

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
    
    // Load custom workout configurations
    final customConfigsJson = p.getString(_kCustomConfigs);
    if (customConfigsJson != null) {
      try {
        final List<dynamic> configsList = json.decode(customConfigsJson);
        _customConfigs = configsList
            .map((config) => WorkoutConfig.fromJson(config))
            .toList();
      } catch (e) {
        // If parsing fails, use empty list and continue
        _customConfigs = [];
      }
    }
    
    // Load selected custom config ID
    _selectedCustomConfigId = p.getString(_kSelectedCustom);
    
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
    
    // Save custom workout configurations
    final customConfigsJson = json.encode(
      _customConfigs.map((config) => config.toJson()).toList()
    );
    await p.setString(_kCustomConfigs, customConfigsJson);
    
    // Save selected custom config ID
    if (_selectedCustomConfigId != null) {
      await p.setString(_kSelectedCustom, _selectedCustomConfigId!);
    } else {
      await p.remove(_kSelectedCustom);
    }
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
    // If using custom configuration, return its range directly
    if (isUsingCustomConfig) {
      final customConfig = selectedCustomConfig!;
      return (customConfig.minHeartRate, customConfig.maxHeartRate);
    }
    
    // Otherwise, use the traditional zone-based calculation
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

  // Custom WorkoutConfig Management Methods

  /// Get all custom workout configurations
  List<WorkoutConfig> get customConfigs => List.unmodifiable(_customConfigs);

  /// Get available default workout configurations based on user profile
  List<WorkoutConfig> get defaultConfigs {
    final maxHR = WorkoutConfigValidator.calculateMaxHeartRate(age);
    return WorkoutConfig.getDefaultConfigs(maxHR: maxHR);
  }

  /// Get all workout configurations (default + custom)
  List<WorkoutConfig> get allConfigs => [...defaultConfigs, ...customConfigs];

  /// Get currently selected custom workout configuration (if any)
  WorkoutConfig? get selectedCustomConfig {
    if (_selectedCustomConfigId == null) return null;
    try {
      return _customConfigs.firstWhere((config) => config.id == _selectedCustomConfigId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a custom workout configuration is currently selected
  bool get isUsingCustomConfig => selectedCustomConfig != null;

  /// Create a new custom workout configuration
  Future<WorkoutConfig> createWorkoutConfig({
    required String name,
    required int minHeartRate,
    required int maxHeartRate,
    required Duration duration,
    required String description,
    int intensityLevel = 3,
    String colorCode = '#2196F3',
  }) async {
    // Generate unique ID based on current timestamp
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    
    final config = WorkoutConfig(
      id: id,
      name: name,
      minHeartRate: minHeartRate,
      maxHeartRate: maxHeartRate,
      duration: duration,
      description: description,
      intensityLevel: intensityLevel,
      colorCode: colorCode,
    );

    // Validate the configuration
    final validationResult = WorkoutConfigValidator.validate(config);
    if (!validationResult.isValid) {
      throw ArgumentError('Invalid workout configuration: ${validationResult.errors.join(', ')}');
    }

    _customConfigs.add(config);
    await _save();
    notifyListeners();
    
    return config;
  }

  /// Update an existing custom workout configuration
  Future<WorkoutConfig> updateWorkoutConfig(
    String id, {
    String? name,
    int? minHeartRate,
    int? maxHeartRate,
    Duration? duration,
    String? description,
    int? intensityLevel,
    String? colorCode,
  }) async {
    final configIndex = _customConfigs.indexWhere((config) => config.id == id);
    if (configIndex == -1) {
      throw ArgumentError('Workout configuration with ID $id not found');
    }

    final existingConfig = _customConfigs[configIndex];
    final updatedConfig = existingConfig.copyWith(
      name: name,
      minHeartRate: minHeartRate,
      maxHeartRate: maxHeartRate,
      duration: duration,
      description: description,
      intensityLevel: intensityLevel,
      colorCode: colorCode,
    );

    // Validate the updated configuration
    final validationResult = WorkoutConfigValidator.validate(updatedConfig);
    if (!validationResult.isValid) {
      throw ArgumentError('Invalid workout configuration: ${validationResult.errors.join(', ')}');
    }

    _customConfigs[configIndex] = updatedConfig;
    await _save();
    notifyListeners();
    
    return updatedConfig;
  }

  /// Delete a custom workout configuration
  Future<bool> deleteWorkoutConfig(String id) async {
    final configIndex = _customConfigs.indexWhere((config) => config.id == id);
    if (configIndex == -1) {
      return false; // Configuration not found
    }

    _customConfigs.removeAt(configIndex);
    
    // If the deleted configuration was selected, clear selection
    if (_selectedCustomConfigId == id) {
      _selectedCustomConfigId = null;
    }

    await _save();
    notifyListeners();
    return true;
  }

  /// Select a custom workout configuration
  Future<void> selectCustomWorkout(String configId) async {
    final config = _customConfigs.firstWhere(
      (config) => config.id == configId,
      orElse: () => throw ArgumentError('Custom workout configuration with ID $configId not found'),
    );

    _selectedCustomConfigId = configId;
    await _save();
    notifyListeners();
  }

  /// Clear custom workout selection (fall back to WorkoutType selection)
  Future<void> clearCustomWorkoutSelection() async {
    _selectedCustomConfigId = null;
    await _save();
    notifyListeners();
  }

  /// Get workout configuration by ID (searches both default and custom)
  WorkoutConfig? getWorkoutConfigById(String id) {
    // Check custom configs first
    try {
      return _customConfigs.firstWhere((config) => config.id == id);
    } catch (e) {
      // Check default configs
      try {
        return defaultConfigs.firstWhere((config) => config.id == id);
      } catch (e) {
        return null;
      }
    }
  }

  /// Generate age-appropriate default configurations
  Future<void> refreshDefaultConfigs() async {
    // This method triggers recalculation of default configs based on current age
    // The getter already uses current age, so we just notify listeners
    notifyListeners();
  }
}
