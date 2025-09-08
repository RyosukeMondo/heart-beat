import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heart_beat/workout/workout_settings.dart';
import 'package:heart_beat/workout/workout_config.dart';
import 'package:heart_beat/player/settings.dart';

// Generate mocks
@GenerateMocks([SharedPreferences])
import 'workout_settings_test.mocks.dart';

void main() {
  group('WorkoutSettings Tests', () {
    late WorkoutSettings workoutSettings;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      workoutSettings = WorkoutSettings();
      mockPrefs = MockSharedPreferences();
      
      // Set up default mock behavior
      when(mockPrefs.getInt(any)).thenReturn(null);
      when(mockPrefs.getString(any)).thenReturn(null);
      when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
      when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
      when(mockPrefs.remove(any)).thenAnswer((_) async => true);
    });

    group('Basic Settings Management', () {
      test('initializes with default values', () {
        expect(workoutSettings.age, 35);
        expect(workoutSettings.gender, Gender.other);
        expect(workoutSettings.restingHr, isNull);
        expect(workoutSettings.selected, WorkoutType.fatBurn);
        expect(workoutSettings.customConfigs, isEmpty);
        expect(workoutSettings.selectedCustomConfig, isNull);
        expect(workoutSettings.isUsingCustomConfig, isFalse);
      });

      test('updates profile correctly', () async {
        // Mock SharedPreferences for testing
        SharedPreferences.setMockInitialValues({});
        
        await workoutSettings.updateProfile(
          age: 25,
          gender: Gender.male,
          restingHr: 60,
        );

        expect(workoutSettings.age, 25);
        expect(workoutSettings.gender, Gender.male);
        expect(workoutSettings.restingHr, 60);
      });

      test('selects workout type correctly', () async {
        SharedPreferences.setMockInitialValues({});
        
        await workoutSettings.selectWorkout(WorkoutType.hiit);
        expect(workoutSettings.selected, WorkoutType.hiit);
      });

      test('computes target range for traditional workout types', () {
        workoutSettings.age = 30;
        workoutSettings.selected = WorkoutType.fatBurn;
        
        final (lower, upper) = workoutSettings.targetRange();
        expect(lower, isA<int>());
        expect(upper, isA<int>());
        expect(lower, lessThan(upper));
      });
    });

    group('Custom Workout Configuration Management', () {
      test('creates custom workout configuration successfully', () async {
        SharedPreferences.setMockInitialValues({});
        
        final config = await workoutSettings.createWorkoutConfig(
          name: 'カスタムワークアウト',
          minHeartRate: 130,
          maxHeartRate: 160,
          duration: const Duration(minutes: 45),
          description: 'テスト用のカスタム設定',
          intensityLevel: 4,
          colorCode: '#FF5722',
        );

        expect(config.name, 'カスタムワークアウト');
        expect(config.minHeartRate, 130);
        expect(config.maxHeartRate, 160);
        expect(config.duration, const Duration(minutes: 45));
        expect(config.description, 'テスト用のカスタム設定');
        expect(config.intensityLevel, 4);
        expect(config.colorCode, '#FF5722');
        expect(config.id, startsWith('custom_'));
        
        expect(workoutSettings.customConfigs, contains(config));
        expect(workoutSettings.customConfigs.length, 1);
      });

      test('throws error for invalid workout configuration', () async {
        SharedPreferences.setMockInitialValues({});
        
        expect(
          () async => await workoutSettings.createWorkoutConfig(
            name: '', // Invalid: empty name
            minHeartRate: 160,
            maxHeartRate: 130, // Invalid: min > max
            duration: const Duration(minutes: 30),
            description: 'Invalid config',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('updates existing custom workout configuration', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create initial config
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Original Name',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Original description',
        );

        // Update the config
        final updatedConfig = await workoutSettings.updateWorkoutConfig(
          config.id,
          name: 'Updated Name',
          minHeartRate: 125,
          description: 'Updated description',
        );

        expect(updatedConfig.name, 'Updated Name');
        expect(updatedConfig.minHeartRate, 125);
        expect(updatedConfig.maxHeartRate, 150); // Unchanged
        expect(updatedConfig.description, 'Updated description');
        
        expect(workoutSettings.customConfigs.first.name, 'Updated Name');
      });

      test('throws error when updating non-existent configuration', () async {
        SharedPreferences.setMockInitialValues({});
        
        expect(
          () async => await workoutSettings.updateWorkoutConfig(
            'non_existent_id',
            name: 'New Name',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('deletes custom workout configuration successfully', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create a config
        final config = await workoutSettings.createWorkoutConfig(
          name: 'To Delete',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Will be deleted',
        );

        expect(workoutSettings.customConfigs.length, 1);

        // Delete the config
        final result = await workoutSettings.deleteWorkoutConfig(config.id);
        expect(result, isTrue);
        expect(workoutSettings.customConfigs.length, 0);
      });

      test('returns false when deleting non-existent configuration', () async {
        SharedPreferences.setMockInitialValues({});
        
        final result = await workoutSettings.deleteWorkoutConfig('non_existent_id');
        expect(result, isFalse);
      });

      test('clears custom selection when deleting selected config', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create and select a config
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Selected Config',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Selected config',
        );

        await workoutSettings.selectCustomWorkout(config.id);
        expect(workoutSettings.isUsingCustomConfig, isTrue);

        // Delete the selected config
        await workoutSettings.deleteWorkoutConfig(config.id);
        expect(workoutSettings.isUsingCustomConfig, isFalse);
        expect(workoutSettings.selectedCustomConfig, isNull);
      });
    });

    group('Custom Workout Selection', () {
      test('selects custom workout configuration', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create a config
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Selectable Config',
          minHeartRate: 130,
          maxHeartRate: 170,
          duration: const Duration(minutes: 40),
          description: 'Test selection',
        );

        await workoutSettings.selectCustomWorkout(config.id);
        
        expect(workoutSettings.isUsingCustomConfig, isTrue);
        expect(workoutSettings.selectedCustomConfig, equals(config));
      });

      test('throws error when selecting non-existent configuration', () async {
        SharedPreferences.setMockInitialValues({});
        
        expect(
          () async => await workoutSettings.selectCustomWorkout('non_existent_id'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('clears custom workout selection', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create and select a config
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Selected Config',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Selected config',
        );

        await workoutSettings.selectCustomWorkout(config.id);
        expect(workoutSettings.isUsingCustomConfig, isTrue);

        await workoutSettings.clearCustomWorkoutSelection();
        expect(workoutSettings.isUsingCustomConfig, isFalse);
        expect(workoutSettings.selectedCustomConfig, isNull);
      });

      test('target range uses custom configuration when selected', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create and select a custom config
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Custom Range',
          minHeartRate: 140,
          maxHeartRate: 180,
          duration: const Duration(minutes: 30),
          description: 'Custom range test',
        );

        await workoutSettings.selectCustomWorkout(config.id);
        
        final (lower, upper) = workoutSettings.targetRange();
        expect(lower, 140);
        expect(upper, 180);
      });
    });

    group('Configuration Getters', () {
      test('returns default configurations based on age', () {
        workoutSettings.age = 30;
        final defaultConfigs = workoutSettings.defaultConfigs;
        
        expect(defaultConfigs.length, 6);
        expect(defaultConfigs.map((c) => c.id), containsAll([
          'recovery', 'fat_burn', 'cardio', 'anaerobic', 'interval', 'maximum'
        ]));
        
        // Check age-appropriate max HR (220 - 30 = 190)
        for (final config in defaultConfigs) {
          expect(config.maxHeartRate, lessThanOrEqualTo(190));
        }
      });

      test('returns all configurations (default + custom)', () async {
        SharedPreferences.setMockInitialValues({});
        workoutSettings.age = 30;
        
        // Create a custom config
        await workoutSettings.createWorkoutConfig(
          name: 'Custom Config',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Custom config',
        );

        final allConfigs = workoutSettings.allConfigs;
        expect(allConfigs.length, 7); // 6 default + 1 custom
        
        final customConfig = allConfigs.firstWhere((c) => c.name == 'Custom Config');
        expect(customConfig, isNotNull);
      });

      test('finds workout configuration by ID', () async {
        SharedPreferences.setMockInitialValues({});
        workoutSettings.age = 30;
        
        // Test default config lookup
        final fatBurnConfig = workoutSettings.getWorkoutConfigById('fat_burn');
        expect(fatBurnConfig, isNotNull);
        expect(fatBurnConfig!.id, 'fat_burn');
        
        // Test custom config lookup
        final customConfig = await workoutSettings.createWorkoutConfig(
          name: 'Findable Config',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Can be found',
        );

        final foundConfig = workoutSettings.getWorkoutConfigById(customConfig.id);
        expect(foundConfig, equals(customConfig));
        
        // Test non-existent config
        final notFound = workoutSettings.getWorkoutConfigById('non_existent');
        expect(notFound, isNull);
      });
    });

    group('Persistence and Loading', () {
      test('loads settings from SharedPreferences', () async {
        // Set up mock data
        SharedPreferences.setMockInitialValues({
          'workout.age': 28,
          'workout.gender': 'female',
          'workout.restingHr': 65,
          'workout.selected': 'hiit',
          'workout.customConfigs': json.encode([
            {
              'id': 'test_config',
              'name': 'Test Config',
              'minHeartRate': 130,
              'maxHeartRate': 160,
              'duration': 1800000, // 30 minutes in milliseconds
              'description': 'Test description',
              'intensityLevel': 3,
              'colorCode': '#2196F3',
            }
          ]),
          'workout.selectedCustom': 'test_config',
        });

        await workoutSettings.load();

        expect(workoutSettings.age, 28);
        expect(workoutSettings.gender, Gender.female);
        expect(workoutSettings.restingHr, 65);
        expect(workoutSettings.selected, WorkoutType.hiit);
        expect(workoutSettings.customConfigs.length, 1);
        expect(workoutSettings.customConfigs.first.name, 'Test Config');
        expect(workoutSettings.isUsingCustomConfig, isTrue);
        expect(workoutSettings.selectedCustomConfig!.id, 'test_config');
      });

      test('handles corrupted JSON data gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'workout.age': 30,
          'workout.customConfigs': 'invalid json data',
        });

        await workoutSettings.load();

        expect(workoutSettings.age, 30);
        expect(workoutSettings.customConfigs, isEmpty);
      });

      test('saves custom configurations to SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create a custom config
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Save Test',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Save test',
        );

        // Select it
        await workoutSettings.selectCustomWorkout(config.id);

        // Verify save was called with correct data
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('workout.customConfigs');
        expect(savedJson, isNotNull);
        
        final savedConfigs = json.decode(savedJson!) as List;
        expect(savedConfigs.length, 1);
        expect(savedConfigs.first['name'], 'Save Test');

        final selectedCustom = prefs.getString('workout.selectedCustom');
        expect(selectedCustom, config.id);
      });
    });

    group('Change Notifications', () {
      test('notifies listeners when profile is updated', () async {
        SharedPreferences.setMockInitialValues({});
        
        bool notified = false;
        workoutSettings.addListener(() {
          notified = true;
        });

        await workoutSettings.updateProfile(age: 25);
        expect(notified, isTrue);
      });

      test('notifies listeners when workout type is selected', () async {
        SharedPreferences.setMockInitialValues({});
        
        bool notified = false;
        workoutSettings.addListener(() {
          notified = true;
        });

        await workoutSettings.selectWorkout(WorkoutType.tempo);
        expect(notified, isTrue);
      });

      test('notifies listeners when custom config is created', () async {
        SharedPreferences.setMockInitialValues({});
        
        bool notified = false;
        workoutSettings.addListener(() {
          notified = true;
        });

        await workoutSettings.createWorkoutConfig(
          name: 'Notification Test',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Test notifications',
        );

        expect(notified, isTrue);
      });

      test('notifies listeners when custom config is updated', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create a config first
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Original',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Original',
        );

        bool notified = false;
        workoutSettings.addListener(() {
          notified = true;
        });

        await workoutSettings.updateWorkoutConfig(
          config.id,
          name: 'Updated',
        );

        expect(notified, isTrue);
      });

      test('notifies listeners when custom config is deleted', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create a config first
        final config = await workoutSettings.createWorkoutConfig(
          name: 'To Delete',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Will be deleted',
        );

        bool notified = false;
        workoutSettings.addListener(() {
          notified = true;
        });

        await workoutSettings.deleteWorkoutConfig(config.id);
        expect(notified, isTrue);
      });

      test('notifies listeners when custom workout is selected', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create a config first
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Selectable',
          minHeartRate: 120,
          maxHeartRate: 150,
          duration: const Duration(minutes: 30),
          description: 'Selectable config',
        );

        bool notified = false;
        workoutSettings.addListener(() {
          notified = true;
        });

        await workoutSettings.selectCustomWorkout(config.id);
        expect(notified, isTrue);
      });

      test('notifies listeners on data load', () async {
        SharedPreferences.setMockInitialValues({
          'workout.age': 25,
        });
        
        bool notified = false;
        workoutSettings.addListener(() {
          notified = true;
        });

        await workoutSettings.load();
        expect(notified, isTrue);
      });
    });

    group('Integration with PlayerSettings', () {
      test('applies workout target range to player settings', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create mock PlayerSettings
        final mockPlayerSettings = MockPlayerSettings();
        when(mockPlayerSettings.update(
          pauseBelow: anyNamed('pauseBelow'),
          normalHigh: anyNamed('normalHigh'),
          linearHigh: anyNamed('linearHigh'),
        )).thenAnswer((_) async {});

        // Set up workout settings
        workoutSettings.age = 30;
        workoutSettings.selected = WorkoutType.fatBurn;

        await workoutSettings.applyToPlayer(mockPlayerSettings);

        // Verify that update was called with appropriate values
        verify(mockPlayerSettings.update(
          pauseBelow: anyNamed('pauseBelow'),
          normalHigh: anyNamed('normalHigh'),
          linearHigh: anyNamed('linearHigh'),
        )).called(1);
      });

      test('applies custom workout range to player settings', () async {
        SharedPreferences.setMockInitialValues({});
        
        // Create mock PlayerSettings
        final mockPlayerSettings = MockPlayerSettings();
        when(mockPlayerSettings.update(
          pauseBelow: anyNamed('pauseBelow'),
          normalHigh: anyNamed('normalHigh'),
          linearHigh: anyNamed('linearHigh'),
        )).thenAnswer((_) async {});

        // Create and select custom config
        final config = await workoutSettings.createWorkoutConfig(
          name: 'Custom Range Test',
          minHeartRate: 140,
          maxHeartRate: 180,
          duration: const Duration(minutes: 30),
          description: 'Custom range for player settings',
        );
        await workoutSettings.selectCustomWorkout(config.id);

        await workoutSettings.applyToPlayer(mockPlayerSettings);

        // Verify the target range comes from custom config
        final (lower, upper) = workoutSettings.targetRange();
        expect(lower, 140);
        expect(upper, 180);

        verify(mockPlayerSettings.update(
          pauseBelow: 135, // lower - 5
          normalHigh: 140, // lower
          linearHigh: 180, // upper
        )).called(1);
      });
    });
  });
}

// Additional mock classes for PlayerSettings
@GenerateMocks([PlayerSettings])
class MockPlayerSettings extends Mock implements PlayerSettings {}