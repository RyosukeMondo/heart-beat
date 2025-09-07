import 'dart:convert';

/// Workout configuration for heart rate-based training
/// 
/// Defines workout profiles with target heart rate zones and durations
/// for different training objectives (fat burn, cardio, interval, etc.)
class WorkoutConfig {
  /// Unique identifier for the workout configuration
  final String id;
  
  /// Human-readable name of the workout (in Japanese)
  final String name;
  
  /// Minimum target heart rate (BPM)
  final int minHeartRate;
  
  /// Maximum target heart rate (BPM)
  final int maxHeartRate;
  
  /// Target workout duration
  final Duration duration;
  
  /// Description of the workout in Japanese
  final String description;
  
  /// Workout intensity level (1-5, where 5 is most intense)
  final int intensityLevel;
  
  /// Color code for UI representation (hex string)
  final String colorCode;

  const WorkoutConfig({
    required this.id,
    required this.name,
    required this.minHeartRate,
    required this.maxHeartRate,
    required this.duration,
    required this.description,
    this.intensityLevel = 3,
    this.colorCode = '#2196F3', // Default blue
  });

  /// Factory constructor for Fat Burn zone (60-70% max HR)
  factory WorkoutConfig.fatBurn({
    int maxHR = 180,
    Duration duration = const Duration(minutes: 30),
  }) {
    return WorkoutConfig(
      id: 'fat_burn',
      name: '脂肪燃焼',
      minHeartRate: (maxHR * 0.60).round(),
      maxHeartRate: (maxHR * 0.70).round(),
      duration: duration,
      description: '脂肪燃焼に最適な低強度有酸素運動です。長時間継続できる強度です。',
      intensityLevel: 2,
      colorCode: '#4CAF50', // Green
    );
  }

  /// Factory constructor for Cardio zone (70-80% max HR)
  factory WorkoutConfig.cardio({
    int maxHR = 180,
    Duration duration = const Duration(minutes: 25),
  }) {
    return WorkoutConfig(
      id: 'cardio',
      name: '有酸素運動',
      minHeartRate: (maxHR * 0.70).round(),
      maxHeartRate: (maxHR * 0.80).round(),
      duration: duration,
      description: '心肺機能向上に効果的な中強度の有酸素運動です。',
      intensityLevel: 3,
      colorCode: '#FF9800', // Orange
    );
  }

  /// Factory constructor for Anaerobic zone (80-90% max HR)
  factory WorkoutConfig.anaerobic({
    int maxHR = 180,
    Duration duration = const Duration(minutes: 15),
  }) {
    return WorkoutConfig(
      id: 'anaerobic',
      name: '無酸素運動',
      minHeartRate: (maxHR * 0.80).round(),
      maxHeartRate: (maxHR * 0.90).round(),
      duration: duration,
      description: '筋力向上とスピードアップに効果的な高強度運動です。',
      intensityLevel: 4,
      colorCode: '#F44336', // Red
    );
  }

  /// Factory constructor for Maximum effort zone (90-100% max HR)
  factory WorkoutConfig.maximum({
    int maxHR = 180,
    Duration duration = const Duration(minutes: 8),
  }) {
    return WorkoutConfig(
      id: 'maximum',
      name: '最大強度',
      minHeartRate: (maxHR * 0.90).round(),
      maxHeartRate: maxHR,
      duration: duration,
      description: '最大心拍数での短時間高強度インターバルトレーニングです。',
      intensityLevel: 5,
      colorCode: '#9C27B0', // Purple
    );
  }

  /// Factory constructor for Recovery zone (50-60% max HR)
  factory WorkoutConfig.recovery({
    int maxHR = 180,
    Duration duration = const Duration(minutes: 20),
  }) {
    return WorkoutConfig(
      id: 'recovery',
      name: 'リカバリー',
      minHeartRate: (maxHR * 0.50).round(),
      maxHeartRate: (maxHR * 0.60).round(),
      duration: duration,
      description: 'アクティブリカバリーとウォーミングアップに最適です。',
      intensityLevel: 1,
      colorCode: '#607D8B', // Blue Grey
    );
  }

  /// Factory constructor for Interval training (alternating zones)
  factory WorkoutConfig.interval({
    int maxHR = 180,
    Duration duration = const Duration(minutes: 20),
  }) {
    return WorkoutConfig(
      id: 'interval',
      name: 'インターバル',
      minHeartRate: (maxHR * 0.70).round(),
      maxHeartRate: (maxHR * 0.85).round(),
      duration: duration,
      description: '高強度と休息を交互に行うインターバルトレーニングです。',
      intensityLevel: 4,
      colorCode: '#FF5722', // Deep Orange
    );
  }

  /// Get default workout configurations
  static List<WorkoutConfig> getDefaultConfigs({int maxHR = 180}) {
    return [
      WorkoutConfig.recovery(maxHR: maxHR),
      WorkoutConfig.fatBurn(maxHR: maxHR),
      WorkoutConfig.cardio(maxHR: maxHR),
      WorkoutConfig.anaerobic(maxHR: maxHR),
      WorkoutConfig.interval(maxHR: maxHR),
      WorkoutConfig.maximum(maxHR: maxHR),
    ];
  }

  /// Check if a given heart rate is within the target zone
  bool isInTargetZone(int heartRate) {
    return heartRate >= minHeartRate && heartRate <= maxHeartRate;
  }

  /// Check if a given heart rate is below the target zone
  bool isBelowTargetZone(int heartRate) {
    return heartRate < minHeartRate;
  }

  /// Check if a given heart rate is above the target zone
  bool isAboveTargetZone(int heartRate) {
    return heartRate > maxHeartRate;
  }

  /// Get the target heart rate zone as a string
  String get targetZoneText => '$minHeartRate-$maxHeartRate BPM';

  /// Get workout duration in minutes
  int get durationInMinutes => duration.inMinutes;

  /// Get duration as formatted string (e.g., "30分", "1時間15分")
  String get durationText {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}時間${minutes}分';
      } else {
        return '${hours}時間';
      }
    } else {
      return '${minutes}分';
    }
  }

  /// Validate heart rate values
  bool get isValid {
    return minHeartRate > 0 &&
           maxHeartRate > 0 &&
           minHeartRate < maxHeartRate &&
           minHeartRate >= 30 &&  // Physiological minimum
           maxHeartRate <= 220 &&  // Physiological maximum
           intensityLevel >= 1 &&
           intensityLevel <= 5;
  }

  /// Create a copy with updated properties
  WorkoutConfig copyWith({
    String? id,
    String? name,
    int? minHeartRate,
    int? maxHeartRate,
    Duration? duration,
    String? description,
    int? intensityLevel,
    String? colorCode,
  }) {
    return WorkoutConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      colorCode: colorCode ?? this.colorCode,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'minHeartRate': minHeartRate,
      'maxHeartRate': maxHeartRate,
      'duration': duration.inMilliseconds,
      'description': description,
      'intensityLevel': intensityLevel,
      'colorCode': colorCode,
    };
  }

  /// Create from JSON map
  factory WorkoutConfig.fromJson(Map<String, dynamic> json) {
    return WorkoutConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      minHeartRate: json['minHeartRate'] as int,
      maxHeartRate: json['maxHeartRate'] as int,
      duration: Duration(milliseconds: json['duration'] as int),
      description: json['description'] as String,
      intensityLevel: json['intensityLevel'] as int? ?? 3,
      colorCode: json['colorCode'] as String? ?? '#2196F3',
    );
  }

  /// Convert to JSON string
  String toJsonString() => json.encode(toJson());

  /// Create from JSON string
  factory WorkoutConfig.fromJsonString(String jsonString) {
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return WorkoutConfig.fromJson(jsonMap);
  }

  @override
  String toString() {
    return 'WorkoutConfig(id: $id, name: $name, zone: $targetZoneText, duration: $durationText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkoutConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Workout configuration validation utilities
class WorkoutConfigValidator {
  /// Validate a workout configuration
  static WorkoutValidationResult validate(WorkoutConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Basic validation
    if (config.name.isEmpty) {
      errors.add('ワークアウト名が空です');
    }

    if (config.minHeartRate <= 0) {
      errors.add('最小心拍数は1以上である必要があります');
    }

    if (config.maxHeartRate <= 0) {
      errors.add('最大心拍数は1以上である必要があります');
    }

    if (config.minHeartRate >= config.maxHeartRate) {
      errors.add('最小心拍数は最大心拍数より小さい必要があります');
    }

    // Physiological validation
    if (config.minHeartRate < 30) {
      warnings.add('最小心拍数が低すぎます（30 BPM未満）');
    }

    if (config.maxHeartRate > 220) {
      warnings.add('最大心拍数が高すぎます（220 BPM超過）');
    }

    // Duration validation
    if (config.duration.inSeconds <= 0) {
      errors.add('ワークアウト時間は0より大きい必要があります');
    }

    if (config.duration.inHours > 4) {
      warnings.add('ワークアウト時間が長すぎます（4時間超過）');
    }

    // Intensity validation
    if (config.intensityLevel < 1 || config.intensityLevel > 5) {
      errors.add('強度レベルは1-5の範囲である必要があります');
    }

    return WorkoutValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Calculate recommended maximum heart rate based on age
  static int calculateMaxHeartRate(int age) {
    // Using the common formula: 220 - age
    // For more accuracy, could use: 208 - (0.7 × age)
    return (220 - age).clamp(100, 220);
  }

  /// Generate age-appropriate workout configurations
  static List<WorkoutConfig> generateAgeAppropriateConfigs(int age) {
    final maxHR = calculateMaxHeartRate(age);
    return WorkoutConfig.getDefaultConfigs(maxHR: maxHR);
  }
}

/// Result of workout configuration validation
class WorkoutValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const WorkoutValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('WorkoutValidationResult(isValid: $isValid)');
    
    if (hasErrors) {
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }
    
    if (hasWarnings) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    
    return buffer.toString();
  }
}