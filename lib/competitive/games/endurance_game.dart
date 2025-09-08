import 'dart:async';
import 'dart:math';
import 'base_game.dart';

/// Endurance Game Implementation
/// 
/// Tests cardiovascular stamina by monitoring sustained heart rate performance
/// over extended periods. Players compete based on time spent in target zones
/// and may face elimination if they fall below minimum thresholds.
class EnduranceGame extends BaseGame {
  // Game-specific configuration
  late final Duration _eliminationGracePeriod;
  late final int _targetZoneMinBPM;
  late final int _targetZoneMaxBPM;
  late final int _eliminationThresholdBPM;
  late final bool _eliminationEnabled;
  late final int _pointsPerSecondInZone;
  
  // Game state tracking
  final Set<String> _eliminatedPlayers = {};
  final Map<String, PlayerEnduranceData> _playerData = {};
  final Map<String, Timer?> _eliminationTimers = {};
  final Map<String, int> _totalScores = {};

  EnduranceGame({
    required String sessionId,
    required GameConfig config,
  }) : super(sessionId: sessionId, config: config);

  @override
  Future<void> _performGameSpecificInitialization(GameConfig config) async {
    // Extract game-specific parameters
    _eliminationGracePeriod = Duration(
      seconds: config.parameters['eliminationGraceSeconds'] as int? ?? 30,
    );
    _targetZoneMinBPM = config.parameters['targetZoneMin'] as int? ?? 120;
    _targetZoneMaxBPM = config.parameters['targetZoneMax'] as int? ?? 160;
    _eliminationThresholdBPM = config.parameters['eliminationThreshold'] as int? ?? 100;
    _eliminationEnabled = config.parameters['eliminationEnabled'] as bool? ?? true;
    _pointsPerSecondInZone = config.parameters['pointsPerSecond'] as int? ?? 10;
    
    // Validate parameters
    if (_targetZoneMinBPM <= 0 || _targetZoneMaxBPM <= 0) {
      throw GameException('Target zone BPM values must be positive');
    }
    if (_targetZoneMinBPM >= _targetZoneMaxBPM) {
      throw GameException('Target zone minimum must be less than maximum');
    }
    if (_eliminationThresholdBPM >= _targetZoneMinBPM) {
      throw GameException('Elimination threshold must be below target zone minimum');
    }
    if (_eliminationGracePeriod.inSeconds < 10) {
      throw GameException('Elimination grace period must be at least 10 seconds');
    }
    
    // Initialize player tracking
    for (final player in players) {
      _playerData[player.playerId] = PlayerEnduranceData(playerId: player.playerId);
      _totalScores[player.playerId] = 0;
      _eliminationTimers[player.playerId] = null;
    }
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'gameType': 'endurance',
        'targetZone': {
          'min': _targetZoneMinBPM,
          'max': _targetZoneMaxBPM,
        },
        'eliminationThreshold': _eliminationThresholdBPM,
        'eliminationEnabled': _eliminationEnabled,
        'gracePeriod': _eliminationGracePeriod.inSeconds,
        'pointsPerSecond': _pointsPerSecondInZone,
        'gameDuration': config.duration.inSeconds,
      },
    ));
  }

  @override
  Future<void> _performGameSpecificStart() async {
    // Start scoring timer - award points every second for players in target zone
    Timer.periodic(const Duration(seconds: 1), _awardEndurancePoints);
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'enduranceGameStarted': true,
        'activePlayers': _playerData.keys.length,
        'targetZoneText': '$_targetZoneMinBPM-$_targetZoneMaxBPM BPM',
      },
    ));
  }

  @override
  void _processGameSpecificHeartRate(String playerId, int bpm) {
    if (_eliminatedPlayers.contains(playerId)) {
      return; // Ignore heart rate from eliminated players
    }
    
    final playerData = _playerData[playerId];
    if (playerData == null) return;
    
    // Update player data
    playerData.updateHeartRate(bpm);
    
    // Check zone status
    final inTargetZone = _isInTargetZone(bpm);
    final belowElimination = _isBelowEliminationThreshold(bpm);
    
    playerData.updateZoneStatus(inTargetZone, belowElimination);
    
    // Handle elimination logic
    if (_eliminationEnabled) {
      _handleEliminationCheck(playerId, bpm, belowElimination);
    }
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.heartRateUpdate,
      timestamp: DateTime.now(),
      data: {
        'playerId': playerId,
        'heartRate': bpm,
        'inTargetZone': inTargetZone,
        'belowElimination': belowElimination,
        'timeInZone': playerData.timeInTargetZone.inSeconds,
        'isEliminated': _eliminatedPlayers.contains(playerId),
      },
    ));
  }

  @override
  Future<void> _performGameSpecificStop() async {
    // Cancel all elimination timers
    for (final timer in _eliminationTimers.values) {
      timer?.cancel();
    }
    _eliminationTimers.clear();
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'gameEnded': true,
        'activePlayers': _playerData.keys.length - _eliminatedPlayers.length,
        'eliminatedPlayers': _eliminatedPlayers.length,
        'finalScores': Map.from(_totalScores),
      },
    ));
  }

  @override
  List<PlayerScore> _calculateCurrentScores() {
    final scores = <PlayerScore>[];
    
    for (final entry in _playerData.entries) {
      final playerId = entry.key;
      final playerData = entry.value;
      final totalScore = _totalScores[playerId]!.toDouble();
      
      scores.add(PlayerScore(
        playerId: playerId,
        score: totalScore,
        rank: 0, // Will be calculated after sorting
        metrics: {
          'totalScore': totalScore,
          'timeInTargetZone': playerData.timeInTargetZone.inSeconds,
          'timeInTargetZonePercent': playerData.getTimeInZonePercentage(gameDuration),
          'averageHeartRate': playerData.getAverageHeartRate(),
          'isEliminated': _eliminatedPlayers.contains(playerId),
          'eliminationTime': playerData.eliminationTime?.toIso8601String(),
        },
      ));
    }
    
    // Sort by score (descending), with non-eliminated players ranked higher
    scores.sort((a, b) {
      final aEliminated = _eliminatedPlayers.contains(a.playerId);
      final bEliminated = _eliminatedPlayers.contains(b.playerId);
      
      if (aEliminated && !bEliminated) return 1;
      if (!aEliminated && bEliminated) return -1;
      
      return b.score.compareTo(a.score);
    });
    
    // Assign ranks
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
      'gameType': 'endurance',
      'gameDuration': gameDuration.inSeconds,
      'targetZone': {
        'min': _targetZoneMinBPM,
        'max': _targetZoneMaxBPM,
      },
      'eliminationThreshold': _eliminationThresholdBPM,
      'totalPlayers': _playerData.length,
      'activePlayers': _playerData.length - _eliminatedPlayers.length,
      'eliminatedPlayers': _eliminatedPlayers.length,
      'eliminatedPlayersList': _eliminatedPlayers.toList(),
      'averageTimeInZone': _calculateAverageTimeInZone(),
      'longestTimeInZone': _findLongestTimeInZone(),
      'playerEnduranceData': _playerData.map(
        (playerId, data) => MapEntry(playerId, data.toJson()),
      ),
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

  bool _isInTargetZone(int bpm) {
    return bpm >= _targetZoneMinBPM && bpm <= _targetZoneMaxBPM;
  }

  bool _isBelowEliminationThreshold(int bpm) {
    return bpm < _eliminationThresholdBPM;
  }

  void _handleEliminationCheck(String playerId, int bpm, bool belowThreshold) {
    if (belowThreshold) {
      // Start elimination countdown if not already started
      if (_eliminationTimers[playerId] == null) {
        _startEliminationCountdown(playerId);
      }
    } else {
      // Cancel elimination countdown if heart rate recovers
      _cancelEliminationCountdown(playerId);
    }
  }

  void _startEliminationCountdown(String playerId) {
    _eliminationTimers[playerId] = Timer(_eliminationGracePeriod, () {
      _eliminatePlayer(playerId);
    });
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'eliminationCountdownStarted': playerId,
        'gracePeriod': _eliminationGracePeriod.inSeconds,
        'threshold': _eliminationThresholdBPM,
      },
    ));
  }

  void _cancelEliminationCountdown(String playerId) {
    _eliminationTimers[playerId]?.cancel();
    _eliminationTimers[playerId] = null;
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'eliminationCountdownCancelled': playerId,
      },
    ));
  }

  void _eliminatePlayer(String playerId) {
    _eliminatedPlayers.add(playerId);
    _eliminationTimers[playerId] = null;
    
    final playerData = _playerData[playerId];
    if (playerData != null) {
      playerData.eliminationTime = DateTime.now();
    }
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'playerEliminated': playerId,
        'eliminationTime': DateTime.now().toIso8601String(),
        'activePlayers': _playerData.keys.length - _eliminatedPlayers.length,
        'finalScore': _totalScores[playerId],
      },
    ));
    
    // Check if only one player remains
    if (_playerData.keys.length - _eliminatedPlayers.length <= 1) {
      _broadcastUpdate(GameUpdate(
        type: GameUpdateType.gameStateChanged,
        timestamp: DateTime.now(),
        data: {
          'lastPlayerStanding': true,
          'remainingPlayers': _playerData.keys.where((id) => !_eliminatedPlayers.contains(id)).toList(),
        },
      ));
    }
  }

  void _awardEndurancePoints(Timer timer) {
    if (currentState != GameState.active) {
      timer.cancel();
      return;
    }
    
    for (final entry in _playerData.entries) {
      final playerId = entry.key;
      final playerData = entry.value;
      
      // Skip eliminated players
      if (_eliminatedPlayers.contains(playerId)) continue;
      
      // Award points if player is in target zone
      if (_isInTargetZone(playerData.currentHeartRate)) {
        playerData.addTimeInTargetZone(const Duration(seconds: 1));
        _totalScores[playerId] = (_totalScores[playerId] ?? 0) + _pointsPerSecondInZone;
      }
    }
    
    // Update scores stream
    _updateScores();
  }

  double _calculateAverageTimeInZone() {
    if (_playerData.isEmpty) return 0.0;
    
    final totalTimeInZone = _playerData.values
        .map((data) => data.timeInTargetZone.inSeconds)
        .reduce((a, b) => a + b);
    
    return totalTimeInZone / _playerData.length;
  }

  Map<String, dynamic> _findLongestTimeInZone() {
    if (_playerData.isEmpty) return {};
    
    String? bestPlayerId;
    Duration longestTime = Duration.zero;
    
    for (final entry in _playerData.entries) {
      if (entry.value.timeInTargetZone > longestTime) {
        longestTime = entry.value.timeInTargetZone;
        bestPlayerId = entry.key;
      }
    }
    
    return {
      'playerId': bestPlayerId,
      'timeInSeconds': longestTime.inSeconds,
    };
  }
}

/// Player-specific endurance tracking data
class PlayerEnduranceData {
  final String playerId;
  int currentHeartRate = 0;
  Duration timeInTargetZone = Duration.zero;
  DateTime? eliminationTime;
  final List<EnduranceReading> heartRateHistory = [];
  bool _currentlyInTargetZone = false;
  DateTime? _targetZoneEntryTime;

  PlayerEnduranceData({required this.playerId});

  void updateHeartRate(int bpm) {
    currentHeartRate = bpm;
    heartRateHistory.add(EnduranceReading(bpm, DateTime.now()));
    
    // Keep only recent history (last 30 minutes to prevent memory issues)
    final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
    heartRateHistory.removeWhere((reading) => reading.timestamp.isBefore(cutoff));
  }

  void updateZoneStatus(bool inTargetZone, bool belowElimination) {
    final now = DateTime.now();
    
    if (inTargetZone && !_currentlyInTargetZone) {
      // Entered target zone
      _currentlyInTargetZone = true;
      _targetZoneEntryTime = now;
    } else if (!inTargetZone && _currentlyInTargetZone) {
      // Exited target zone
      _currentlyInTargetZone = false;
      if (_targetZoneEntryTime != null) {
        final duration = now.difference(_targetZoneEntryTime!);
        timeInTargetZone += duration;
        _targetZoneEntryTime = null;
      }
    }
  }

  void addTimeInTargetZone(Duration additionalTime) {
    timeInTargetZone += additionalTime;
  }

  double getTimeInZonePercentage(Duration totalGameTime) {
    if (totalGameTime.inSeconds == 0) return 0.0;
    return (timeInTargetZone.inSeconds / totalGameTime.inSeconds) * 100;
  }

  double getAverageHeartRate() {
    if (heartRateHistory.isEmpty) return currentHeartRate.toDouble();
    
    final total = heartRateHistory
        .map((reading) => reading.bpm)
        .reduce((a, b) => a + b);
    
    return total / heartRateHistory.length;
  }

  List<int> getRecentHeartRates(Duration period) {
    final cutoff = DateTime.now().subtract(period);
    return heartRateHistory
        .where((reading) => reading.timestamp.isAfter(cutoff))
        .map((reading) => reading.bpm)
        .toList();
  }

  double getHeartRateVariability(Duration period) {
    final readings = getRecentHeartRates(period);
    if (readings.length < 2) return 0.0;
    
    final mean = readings.reduce((a, b) => a + b) / readings.length;
    final variance = readings
        .map((reading) => pow(reading - mean, 2))
        .reduce((a, b) => a + b) / readings.length;
    
    return sqrt(variance);
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'currentHeartRate': currentHeartRate,
      'timeInTargetZone': timeInTargetZone.inSeconds,
      'eliminationTime': eliminationTime?.toIso8601String(),
      'averageHeartRate': getAverageHeartRate(),
      'heartRateVariability': getHeartRateVariability(const Duration(minutes: 5)),
      'totalReadings': heartRateHistory.length,
      'currentlyInTargetZone': _currentlyInTargetZone,
    };
  }
}

/// Individual endurance heart rate reading
class EnduranceReading {
  final int bpm;
  final DateTime timestamp;

  EnduranceReading(this.bpm, this.timestamp);
}