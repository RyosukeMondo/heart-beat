import 'dart:async';
import 'dart:math';
import 'base_game.dart';
import '../../workout/workout_config.dart';

/// Resilience Game Implementation
/// 
/// Tests cardiovascular stability by measuring players' ability to maintain
/// steady heart rates within specified zones during various stress phases.
/// Players compete based on heart rate variability and zone maintenance.
class ResilienceGame extends BaseGame {
  // Game-specific configuration
  late final List<StressPhase> _stressPhases;
  late final int _targetHeartRateZoneWidth;
  late final double _maxAllowableVariability;
  late final Duration _measurementWindow;
  
  // Game state tracking
  int _currentPhaseIndex = 0;
  StressPhase? _currentPhase;
  DateTime? _phaseStartTime;
  Timer? _phaseTimer;
  Timer? _measurementTimer;
  
  // Player stability tracking
  final Map<String, PlayerResilienceData> _playerData = {};
  final Map<String, List<double>> _stabilityScores = {};
  final Map<String, int> _totalScores = {};

  ResilienceGame({
    required String sessionId,
    required GameConfig config,
  }) : super(sessionId: sessionId, config: config);

  @override
  Future<void> _performGameSpecificInitialization(GameConfig config) async {
    // Extract game-specific parameters
    final phases = config.parameters['phases'] as List<Map<String, dynamic>>? ?? _getDefaultPhases();
    _stressPhases = phases.map((phaseData) => StressPhase.fromJson(phaseData)).toList();
    
    _targetHeartRateZoneWidth = config.parameters['zoneWidth'] as int? ?? 20;
    _maxAllowableVariability = (config.parameters['maxVariability'] as num? ?? 15.0).toDouble();
    _measurementWindow = Duration(
      seconds: config.parameters['measurementWindowSeconds'] as int? ?? 10,
    );
    
    // Validate parameters
    if (_stressPhases.isEmpty) {
      throw GameException('At least one stress phase must be defined');
    }
    if (_targetHeartRateZoneWidth < 10 || _targetHeartRateZoneWidth > 50) {
      throw GameException('Heart rate zone width must be between 10-50 BPM, got $_targetHeartRateZoneWidth');
    }
    if (_maxAllowableVariability < 5.0 || _maxAllowableVariability > 30.0) {
      throw GameException('Max allowable variability must be between 5.0-30.0, got $_maxAllowableVariability');
    }
    
    // Initialize player tracking
    for (final player in players) {
      _playerData[player.playerId] = PlayerResilienceData(playerId: player.playerId);
      _stabilityScores[player.playerId] = [];
      _totalScores[player.playerId] = 0;
    }
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'gameType': 'resilience',
        'phases': _stressPhases.map((p) => p.toJson()).toList(),
        'zoneWidth': _targetHeartRateZoneWidth,
        'maxVariability': _maxAllowableVariability,
        'measurementWindow': _measurementWindow.inSeconds,
      },
    ));
  }

  @override
  Future<void> _performGameSpecificStart() async {
    _currentPhaseIndex = 0;
    await _startNextPhase();
    
    // Start measurement timer for continuous stability assessment
    _measurementTimer = Timer.periodic(_measurementWindow, _measureStability);
  }

  @override
  void _processGameSpecificHeartRate(String playerId, int bpm) {
    final playerData = _playerData[playerId];
    if (playerData == null || _currentPhase == null) return;
    
    // Record heart rate data
    playerData.addHeartRateReading(bpm);
    
    // Calculate target zone for current phase
    final targetZone = _calculateTargetZone(playerData, _currentPhase!);
    
    // Update zone maintenance tracking
    final inZone = bpm >= targetZone.minHeartRate && bpm <= targetZone.maxHeartRate;
    playerData.updateZoneMaintenance(inZone);
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.heartRateUpdate,
      timestamp: DateTime.now(),
      data: {
        'playerId': playerId,
        'heartRate': bpm,
        'targetZone': {
          'min': targetZone.minHeartRate,
          'max': targetZone.maxHeartRate,
        },
        'inZone': inZone,
        'phase': _currentPhase!.name,
      },
    ));
  }

  @override
  Future<void> _performGameSpecificStop() async {
    _phaseTimer?.cancel();
    _measurementTimer?.cancel();
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'gameEnded': true,
        'completedPhases': _currentPhaseIndex,
        'totalPhases': _stressPhases.length,
      },
    ));
  }

  @override
  List<PlayerScore> _calculateCurrentScores() {
    final scores = <PlayerScore>[];
    
    for (final playerId in _totalScores.keys) {
      final totalScore = _totalScores[playerId]!.toDouble();
      final playerData = _playerData[playerId]!;
      
      scores.add(PlayerScore(
        playerId: playerId,
        score: totalScore,
        rank: 0, // Will be calculated after sorting
        metrics: {
          'totalScore': totalScore,
          'overallStability': playerData.getOverallStabilityScore(),
          'zoneMaintenancePercentage': playerData.getZoneMaintenancePercentage(),
          'currentVariability': playerData.getCurrentVariability(),
          'phase': _currentPhase?.name ?? 'none',
        },
      ));
    }
    
    // Sort by score (descending) and assign ranks
    scores.sort((a, b) => b.score.compareTo(a.score));
    for (int i = 0; i < scores.length; i++) {
      scores[i] = PlayerScore(
        playerId: scores[i].playerId,
        score: scores[i].score,
        rank: i + 1,
        metrics: scores[i].metrics,
      );
    }
    
    return scores;
  }

  @override
  Future<GameResult> calculateResults() async {
    final finalScores = _calculateCurrentScores();
    
    if (finalScores.isEmpty) {
      throw GameException('No players found for result calculation');
    }
    
    final winner = finalScores.first;
    
    // Calculate detailed game metrics
    final gameMetrics = <String, dynamic>{
      'gameType': 'resilience',
      'completedPhases': _currentPhaseIndex,
      'totalPhases': _stressPhases.length,
      'phases': _stressPhases.map((p) => p.toJson()).toList(),
      'playerStabilityData': _playerData.map(
        (playerId, data) => MapEntry(playerId, data.toJson()),
      ),
      'stabilityScores': _stabilityScores,
      'overallStabilityAverage': _calculateOverallStabilityAverage(),
    };
    
    return GameResult(
      sessionId: sessionId,
      scores: finalScores,
      winner: winner,
      gameDuration: gameDuration,
      completedAt: DateTime.now(),
      gameMetrics: gameMetrics,
    );
  }

  // Private helper methods

  Future<void> _startNextPhase() async {
    if (_currentPhaseIndex >= _stressPhases.length) {
      await stop();
      return;
    }
    
    _currentPhase = _stressPhases[_currentPhaseIndex];
    _phaseStartTime = DateTime.now();
    
    // Reset phase-specific tracking
    for (final playerData in _playerData.values) {
      playerData.startNewPhase(_currentPhase!.name);
    }
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'phaseStarted': _currentPhase!.name,
        'phaseIndex': _currentPhaseIndex + 1,
        'totalPhases': _stressPhases.length,
        'phaseDuration': _currentPhase!.duration.inSeconds,
        'phaseDescription': _currentPhase!.description,
        'difficultyMultiplier': _currentPhase!.difficultyMultiplier,
      },
    ));
    
    // Set timer for phase completion
    _phaseTimer = Timer(_currentPhase!.duration, _endCurrentPhase);
  }

  void _endCurrentPhase() {
    if (_currentPhase == null) return;
    
    // Calculate phase scores
    _calculatePhaseResults();
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'phaseEnded': _currentPhase!.name,
        'phaseScores': _getPhaseScores(),
        'totalScores': Map.from(_totalScores),
      },
    ));
    
    _currentPhaseIndex++;
    
    // Start next phase after brief pause
    Timer(const Duration(seconds: 2), _startNextPhase);
  }

  void _measureStability(Timer timer) {
    if (_currentPhase == null) return;
    
    for (final entry in _playerData.entries) {
      final playerId = entry.key;
      final playerData = entry.value;
      
      final stabilityScore = playerData.calculateStabilityScore(_measurementWindow);
      _stabilityScores[playerId]?.add(stabilityScore);
      
      // Award points for good stability during this measurement window
      final points = _calculateStabilityPoints(stabilityScore, _currentPhase!.difficultyMultiplier);
      _totalScores[playerId] = (_totalScores[playerId] ?? 0) + points;
    }
    
    // Update scores stream
    _updateScores();
  }

  HeartRateZone _calculateTargetZone(PlayerResilienceData playerData, StressPhase phase) {
    // Calculate personal target zone based on player's recent heart rate history
    final recentReadings = playerData.getRecentHeartRateReadings(const Duration(minutes: 2));
    
    int baselineHR;
    if (recentReadings.isNotEmpty) {
      baselineHR = (recentReadings.reduce((a, b) => a + b) / recentReadings.length).round();
    } else {
      baselineHR = playerData.currentHeartRate;
    }
    
    // Adjust baseline based on phase stress level
    final adjustedBaseline = (baselineHR * phase.targetIntensityMultiplier).round();
    final halfZoneWidth = _targetHeartRateZoneWidth ~/ 2;
    
    return HeartRateZone(
      minHeartRate: adjustedBaseline - halfZoneWidth,
      maxHeartRate: adjustedBaseline + halfZoneWidth,
    );
  }

  void _calculatePhaseResults() {
    for (final entry in _playerData.entries) {
      final playerId = entry.key;
      final playerData = entry.value;
      
      // Calculate phase-specific metrics
      final zoneMaintenanceScore = playerData.getZoneMaintenancePercentage() * 100;
      final stabilityBonus = (100 - playerData.getCurrentVariability()).clamp(0, 100);
      final consistencyBonus = playerData.getConsistencyBonus();
      
      // Apply difficulty multiplier
      final basePhaseScore = (zoneMaintenanceScore + stabilityBonus + consistencyBonus).round();
      final finalPhaseScore = (basePhaseScore * _currentPhase!.difficultyMultiplier).round();
      
      _totalScores[playerId] = (_totalScores[playerId] ?? 0) + finalPhaseScore;
    }
  }

  int _calculateStabilityPoints(double stabilityScore, double difficultyMultiplier) {
    // Higher stability score = more points
    // Scale: 0-100 stability score -> 0-10 base points
    final basePoints = (stabilityScore / 10).round().clamp(0, 10);
    return (basePoints * difficultyMultiplier).round();
  }

  Map<String, int> _getPhaseScores() {
    // Return the score gained in the current phase for each player
    return _totalScores.map((playerId, totalScore) => MapEntry(playerId, totalScore));
  }

  double _calculateOverallStabilityAverage() {
    if (_playerData.isEmpty) return 0.0;
    
    final totalStability = _playerData.values
        .map((data) => data.getOverallStabilityScore())
        .reduce((a, b) => a + b);
    
    return totalStability / _playerData.length;
  }

  List<Map<String, dynamic>> _getDefaultPhases() {
    return [
      {
        'name': 'Warm-up',
        'duration': 60000, // 1 minute in milliseconds
        'description': 'Establish baseline heart rate stability',
        'targetIntensityMultiplier': 1.0,
        'difficultyMultiplier': 1.0,
      },
      {
        'name': 'Light Stress',
        'duration': 120000, // 2 minutes
        'description': 'Maintain stability under light cardiovascular stress',
        'targetIntensityMultiplier': 1.1,
        'difficultyMultiplier': 1.2,
      },
      {
        'name': 'Moderate Stress',
        'duration': 180000, // 3 minutes
        'description': 'Demonstrate resilience during moderate stress phase',
        'targetIntensityMultiplier': 1.2,
        'difficultyMultiplier': 1.5,
      },
      {
        'name': 'High Stress',
        'duration': 120000, // 2 minutes
        'description': 'Maintain control under high cardiovascular stress',
        'targetIntensityMultiplier': 1.3,
        'difficultyMultiplier': 2.0,
      },
      {
        'name': 'Recovery',
        'duration': 90000, // 1.5 minutes
        'description': 'Demonstrate quick recovery and return to baseline',
        'targetIntensityMultiplier': 0.9,
        'difficultyMultiplier': 1.3,
      },
    ];
  }
}

/// Represents a stress phase in the resilience game
class StressPhase {
  final String name;
  final Duration duration;
  final String description;
  final double targetIntensityMultiplier;
  final double difficultyMultiplier;

  const StressPhase({
    required this.name,
    required this.duration,
    required this.description,
    required this.targetIntensityMultiplier,
    required this.difficultyMultiplier,
  });

  factory StressPhase.fromJson(Map<String, dynamic> json) {
    return StressPhase(
      name: json['name'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      description: json['description'] as String,
      targetIntensityMultiplier: (json['targetIntensityMultiplier'] as num).toDouble(),
      difficultyMultiplier: (json['difficultyMultiplier'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'duration': duration.inMilliseconds,
      'description': description,
      'targetIntensityMultiplier': targetIntensityMultiplier,
      'difficultyMultiplier': difficultyMultiplier,
    };
  }
}

/// Heart rate zone definition (reusing WorkoutConfig patterns)
class HeartRateZone {
  final int minHeartRate;
  final int maxHeartRate;

  const HeartRateZone({
    required this.minHeartRate,
    required this.maxHeartRate,
  });

  bool contains(int heartRate) {
    return heartRate >= minHeartRate && heartRate <= maxHeartRate;
  }

  String get targetZoneText => '$minHeartRate-$maxHeartRate BPM';
}

/// Player-specific resilience data tracking
class PlayerResilienceData {
  final String playerId;
  int currentHeartRate = 0;
  final List<HeartRateReading> heartRateHistory = [];
  final Map<String, PhaseData> phaseData = {};
  String? currentPhase;

  PlayerResilienceData({required this.playerId});

  void addHeartRateReading(int bpm) {
    currentHeartRate = bpm;
    heartRateHistory.add(HeartRateReading(bpm, DateTime.now()));
    
    // Keep only recent history (last 10 minutes)
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    heartRateHistory.removeWhere((reading) => reading.timestamp.isBefore(cutoff));
  }

  void startNewPhase(String phaseName) {
    currentPhase = phaseName;
    phaseData[phaseName] = PhaseData(phaseName);
  }

  void updateZoneMaintenance(bool inZone) {
    if (currentPhase != null && phaseData.containsKey(currentPhase!)) {
      phaseData[currentPhase!]!.updateZoneMaintenance(inZone);
    }
  }

  List<int> getRecentHeartRateReadings(Duration period) {
    final cutoff = DateTime.now().subtract(period);
    return heartRateHistory
        .where((reading) => reading.timestamp.isAfter(cutoff))
        .map((reading) => reading.bpm)
        .toList();
  }

  double calculateStabilityScore(Duration window) {
    final readings = getRecentHeartRateReadings(window);
    if (readings.length < 2) return 0.0;
    
    // Calculate coefficient of variation (CV) as stability metric
    final mean = readings.reduce((a, b) => a + b) / readings.length;
    final variance = readings
        .map((reading) => pow(reading - mean, 2))
        .reduce((a, b) => a + b) / readings.length;
    final standardDeviation = sqrt(variance);
    
    // Convert CV to stability score (lower CV = higher stability)
    final coefficientOfVariation = standardDeviation / mean;
    return max(0, 100 - (coefficientOfVariation * 100));
  }

  double getCurrentVariability() {
    return 100 - calculateStabilityScore(const Duration(minutes: 1));
  }

  double getOverallStabilityScore() {
    if (heartRateHistory.length < 10) return 0.0;
    
    final allReadings = heartRateHistory.map((r) => r.bpm).toList();
    final mean = allReadings.reduce((a, b) => a + b) / allReadings.length;
    final variance = allReadings
        .map((reading) => pow(reading - mean, 2))
        .reduce((a, b) => a + b) / allReadings.length;
    final standardDeviation = sqrt(variance);
    
    final coefficientOfVariation = standardDeviation / mean;
    return max(0, 100 - (coefficientOfVariation * 100));
  }

  double getZoneMaintenancePercentage() {
    if (currentPhase == null || !phaseData.containsKey(currentPhase!)) {
      return 0.0;
    }
    return phaseData[currentPhase!]!.getZoneMaintenancePercentage();
  }

  double getConsistencyBonus() {
    // Award bonus points for maintaining consistent performance across phases
    if (phaseData.length < 2) return 0.0;
    
    final maintenanceScores = phaseData.values
        .map((data) => data.getZoneMaintenancePercentage())
        .toList();
    
    final mean = maintenanceScores.reduce((a, b) => a + b) / maintenanceScores.length;
    final variance = maintenanceScores
        .map((score) => pow(score - mean, 2))
        .reduce((a, b) => a + b) / maintenanceScores.length;
    
    // Lower variance = higher consistency bonus
    return max(0, 50 - (variance * 5));
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'currentHeartRate': currentHeartRate,
      'overallStabilityScore': getOverallStabilityScore(),
      'currentVariability': getCurrentVariability(),
      'zoneMaintenancePercentage': getZoneMaintenancePercentage(),
      'phaseData': phaseData.map((key, value) => MapEntry(key, value.toJson())),
      'heartRateHistoryLength': heartRateHistory.length,
    };
  }
}

/// Phase-specific tracking data
class PhaseData {
  final String phaseName;
  int totalMeasurements = 0;
  int inZoneMeasurements = 0;

  PhaseData(this.phaseName);

  void updateZoneMaintenance(bool inZone) {
    totalMeasurements++;
    if (inZone) {
      inZoneMeasurements++;
    }
  }

  double getZoneMaintenancePercentage() {
    if (totalMeasurements == 0) return 0.0;
    return inZoneMeasurements / totalMeasurements;
  }

  Map<String, dynamic> toJson() {
    return {
      'phaseName': phaseName,
      'totalMeasurements': totalMeasurements,
      'inZoneMeasurements': inZoneMeasurements,
      'zoneMaintenancePercentage': getZoneMaintenancePercentage(),
    };
  }
}

/// Individual heart rate reading with timestamp
class HeartRateReading {
  final int bpm;
  final DateTime timestamp;

  HeartRateReading(this.bpm, this.timestamp);
}