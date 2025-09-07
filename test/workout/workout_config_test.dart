import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/workout/workout_config.dart';

void main() {
  group('WorkoutConfig Tests', () {
    test('creates workout config with all properties', () {
      const config = WorkoutConfig(
        id: 'test_workout',
        name: 'テストワークアウト',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'テスト用のワークアウト設定です',
        intensityLevel: 3,
        colorCode: '#FF0000',
      );

      expect(config.id, 'test_workout');
      expect(config.name, 'テストワークアウト');
      expect(config.minHeartRate, 120);
      expect(config.maxHeartRate, 150);
      expect(config.duration, const Duration(minutes: 30));
      expect(config.description, 'テスト用のワークアウト設定です');
      expect(config.intensityLevel, 3);
      expect(config.colorCode, '#FF0000');
    });

    test('factory constructors create correct configurations', () {
      // Test fat burn configuration
      final fatBurn = WorkoutConfig.fatBurn(maxHR: 180, duration: const Duration(minutes: 45));
      expect(fatBurn.id, 'fat_burn');
      expect(fatBurn.name, '脂肪燃焼');
      expect(fatBurn.minHeartRate, 108); // 60% of 180
      expect(fatBurn.maxHeartRate, 126); // 70% of 180
      expect(fatBurn.duration, const Duration(minutes: 45));
      expect(fatBurn.intensityLevel, 2);

      // Test cardio configuration
      final cardio = WorkoutConfig.cardio(maxHR: 180);
      expect(cardio.id, 'cardio');
      expect(cardio.name, '有酸素運動');
      expect(cardio.minHeartRate, 126); // 70% of 180
      expect(cardio.maxHeartRate, 144); // 80% of 180
      expect(cardio.intensityLevel, 3);

      // Test anaerobic configuration
      final anaerobic = WorkoutConfig.anaerobic(maxHR: 180);
      expect(anaerobic.id, 'anaerobic');
      expect(anaerobic.minHeartRate, 144); // 80% of 180
      expect(anaerobic.maxHeartRate, 162); // 90% of 180
      expect(anaerobic.intensityLevel, 4);

      // Test maximum configuration
      final maximum = WorkoutConfig.maximum(maxHR: 180);
      expect(maximum.id, 'maximum');
      expect(maximum.minHeartRate, 162); // 90% of 180
      expect(maximum.maxHeartRate, 180); // 100% of 180
      expect(maximum.intensityLevel, 5);

      // Test recovery configuration
      final recovery = WorkoutConfig.recovery(maxHR: 180);
      expect(recovery.id, 'recovery');
      expect(recovery.minHeartRate, 90); // 50% of 180
      expect(recovery.maxHeartRate, 108); // 60% of 180
      expect(recovery.intensityLevel, 1);
    });

    test('getDefaultConfigs returns all workout types', () {
      final configs = WorkoutConfig.getDefaultConfigs(maxHR: 180);
      
      expect(configs.length, 6);
      expect(configs.map((c) => c.id), containsAll([
        'recovery', 'fat_burn', 'cardio', 'anaerobic', 'interval', 'maximum'
      ]));
    });

    test('heart rate zone validation works correctly', () {
      const config = WorkoutConfig(
        id: 'test',
        name: 'Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'Test config',
      );

      // Test in target zone
      expect(config.isInTargetZone(130), isTrue);
      expect(config.isInTargetZone(120), isTrue); // Boundary
      expect(config.isInTargetZone(150), isTrue); // Boundary

      // Test below target zone
      expect(config.isBelowTargetZone(110), isTrue);
      expect(config.isBelowTargetZone(119), isTrue);
      expect(config.isBelowTargetZone(120), isFalse); // Boundary

      // Test above target zone
      expect(config.isAboveTargetZone(160), isTrue);
      expect(config.isAboveTargetZone(151), isTrue);
      expect(config.isAboveTargetZone(150), isFalse); // Boundary
    });

    test('target zone text formatting works', () {
      const config = WorkoutConfig(
        id: 'test',
        name: 'Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'Test config',
      );

      expect(config.targetZoneText, '120-150 BPM');
    });

    test('duration formatting works correctly', () {
      // Test minutes only
      const config1 = WorkoutConfig(
        id: 'test',
        name: 'Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 45),
        description: 'Test config',
      );
      expect(config1.durationText, '45分');

      // Test hours only
      const config2 = WorkoutConfig(
        id: 'test',
        name: 'Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(hours: 2),
        description: 'Test config',
      );
      expect(config2.durationText, '2時間');

      // Test hours and minutes
      const config3 = WorkoutConfig(
        id: 'test',
        name: 'Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(hours: 1, minutes: 30),
        description: 'Test config',
      );
      expect(config3.durationText, '1時間30分');
    });

    test('validation works correctly', () {
      // Valid configuration
      const validConfig = WorkoutConfig(
        id: 'valid',
        name: 'Valid Config',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'Valid configuration',
        intensityLevel: 3,
      );
      expect(validConfig.isValid, isTrue);

      // Invalid: min >= max
      const invalidConfig1 = WorkoutConfig(
        id: 'invalid1',
        name: 'Invalid Config',
        minHeartRate: 150,
        maxHeartRate: 120,
        duration: Duration(minutes: 30),
        description: 'Invalid configuration',
      );
      expect(invalidConfig1.isValid, isFalse);

      // Invalid: heart rates out of physiological range
      const invalidConfig2 = WorkoutConfig(
        id: 'invalid2',
        name: 'Invalid Config',
        minHeartRate: 10,
        maxHeartRate: 250,
        duration: Duration(minutes: 30),
        description: 'Invalid configuration',
      );
      expect(invalidConfig2.isValid, isFalse);
    });

    test('copyWith works correctly', () {
      const original = WorkoutConfig(
        id: 'original',
        name: 'Original',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'Original config',
      );

      final updated = original.copyWith(
        name: 'Updated',
        minHeartRate: 130,
      );

      expect(updated.id, 'original'); // Unchanged
      expect(updated.name, 'Updated'); // Changed
      expect(updated.minHeartRate, 130); // Changed
      expect(updated.maxHeartRate, 150); // Unchanged
      expect(updated.duration, const Duration(minutes: 30)); // Unchanged
    });

    test('JSON serialization works correctly', () {
      const config = WorkoutConfig(
        id: 'test_json',
        name: 'JSON Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'JSON serialization test',
        intensityLevel: 4,
        colorCode: '#00FF00',
      );

      // Test toJson
      final json = config.toJson();
      expect(json['id'], 'test_json');
      expect(json['name'], 'JSON Test');
      expect(json['minHeartRate'], 120);
      expect(json['maxHeartRate'], 150);
      expect(json['duration'], 1800000); // 30 minutes in milliseconds
      expect(json['description'], 'JSON serialization test');
      expect(json['intensityLevel'], 4);
      expect(json['colorCode'], '#00FF00');

      // Test fromJson
      final restored = WorkoutConfig.fromJson(json);
      expect(restored.id, config.id);
      expect(restored.name, config.name);
      expect(restored.minHeartRate, config.minHeartRate);
      expect(restored.maxHeartRate, config.maxHeartRate);
      expect(restored.duration, config.duration);
      expect(restored.description, config.description);
      expect(restored.intensityLevel, config.intensityLevel);
      expect(restored.colorCode, config.colorCode);
    });

    test('JSON string serialization works correctly', () {
      const config = WorkoutConfig(
        id: 'string_test',
        name: 'String Test',
        minHeartRate: 100,
        maxHeartRate: 140,
        duration: Duration(minutes: 25),
        description: 'String serialization test',
      );

      final jsonString = config.toJsonString();
      expect(jsonString, isA<String>());
      
      final restored = WorkoutConfig.fromJsonString(jsonString);
      expect(restored.id, config.id);
      expect(restored.name, config.name);
      expect(restored.minHeartRate, config.minHeartRate);
      expect(restored.maxHeartRate, config.maxHeartRate);
      expect(restored.duration, config.duration);
    });

    test('equality and hashCode work correctly', () {
      const config1 = WorkoutConfig(
        id: 'test_equality',
        name: 'Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'Test config',
      );

      const config2 = WorkoutConfig(
        id: 'test_equality',
        name: 'Different Name', // Different properties
        minHeartRate: 100,
        maxHeartRate: 160,
        duration: Duration(minutes: 45),
        description: 'Different config',
      );

      const config3 = WorkoutConfig(
        id: 'different_id',
        name: 'Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'Test config',
      );

      // Same ID means equal (equality based on ID)
      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));

      // Different ID means not equal
      expect(config1, isNot(equals(config3)));
      expect(config1.hashCode, isNot(equals(config3.hashCode)));
    });

    test('toString provides useful information', () {
      const config = WorkoutConfig(
        id: 'string_test',
        name: 'String Test',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'String test',
      );

      final str = config.toString();
      expect(str, contains('string_test'));
      expect(str, contains('String Test'));
      expect(str, contains('120-150 BPM'));
      expect(str, contains('30分'));
    });
  });

  group('WorkoutConfigValidator Tests', () {
    test('validates correct configurations', () {
      const validConfig = WorkoutConfig(
        id: 'valid',
        name: 'Valid Config',
        minHeartRate: 120,
        maxHeartRate: 150,
        duration: Duration(minutes: 30),
        description: 'Valid configuration',
        intensityLevel: 3,
      );

      final result = WorkoutConfigValidator.validate(validConfig);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('detects validation errors', () {
      const invalidConfig = WorkoutConfig(
        id: 'invalid',
        name: '', // Empty name
        minHeartRate: 0, // Invalid heart rate
        maxHeartRate: -10, // Invalid heart rate
        duration: Duration(seconds: 0), // Zero duration
        description: 'Invalid configuration',
        intensityLevel: 10, // Invalid intensity
      );

      final result = WorkoutConfigValidator.validate(invalidConfig);
      expect(result.isValid, isFalse);
      expect(result.errors.length, greaterThan(0));
      expect(result.errors.any((e) => e.contains('ワークアウト名が空です')), isTrue);
    });

    test('detects validation warnings', () {
      const warningConfig = WorkoutConfig(
        id: 'warning',
        name: 'Warning Config',
        minHeartRate: 25, // Below physiological minimum
        maxHeartRate: 250, // Above physiological maximum
        duration: Duration(hours: 5), // Very long duration
        description: 'Configuration with warnings',
      );

      final result = WorkoutConfigValidator.validate(warningConfig);
      expect(result.warnings, isNotEmpty);
    });

    test('calculates maximum heart rate correctly', () {
      expect(WorkoutConfigValidator.calculateMaxHeartRate(20), 200);
      expect(WorkoutConfigValidator.calculateMaxHeartRate(30), 190);
      expect(WorkoutConfigValidator.calculateMaxHeartRate(40), 180);
      expect(WorkoutConfigValidator.calculateMaxHeartRate(50), 170);
      
      // Test edge cases
      expect(WorkoutConfigValidator.calculateMaxHeartRate(0), 220);
      expect(WorkoutConfigValidator.calculateMaxHeartRate(100), 120); // Clamped to minimum
    });

    test('generates age-appropriate configurations', () {
      final configs = WorkoutConfigValidator.generateAgeAppropriateConfigs(30);
      final maxHR = WorkoutConfigValidator.calculateMaxHeartRate(30); // 190
      
      expect(configs.length, 6);
      
      // Check that all configurations use age-appropriate max HR
      for (final config in configs) {
        expect(config.maxHeartRate, lessThanOrEqualTo(maxHR));
      }

      // Check specific zones for 30-year-old (max HR = 190)
      final fatBurnConfig = configs.firstWhere((c) => c.id == 'fat_burn');
      expect(fatBurnConfig.minHeartRate, 114); // 60% of 190
      expect(fatBurnConfig.maxHeartRate, 133); // 70% of 190
    });
  });

  group('WorkoutValidationResult Tests', () {
    test('creates validation result correctly', () {
      const result = WorkoutValidationResult(
        isValid: false,
        errors: ['エラー1', 'エラー2'],
        warnings: ['警告1'],
      );

      expect(result.isValid, isFalse);
      expect(result.hasErrors, isTrue);
      expect(result.hasWarnings, isTrue);
      expect(result.errors.length, 2);
      expect(result.warnings.length, 1);
    });

    test('toString provides useful information', () {
      const result = WorkoutValidationResult(
        isValid: false,
        errors: ['Test error'],
        warnings: ['Test warning'],
      );

      final str = result.toString();
      expect(str, contains('isValid: false'));
      expect(str, contains('Test error'));
      expect(str, contains('Test warning'));
    });
  });
}