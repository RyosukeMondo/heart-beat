import 'dart:async';
import 'dart:math';
import 'base_game.dart';

/// 瞬発力 (Instant Response) Game Implementation
/// 
/// Tests cardiovascular reactivity by measuring how quickly players' heart rates
/// respond to synchronized stimuli. Players compete based on reaction speed
/// and magnitude of heart rate changes.
class InstantResponseGame extends BaseGame {
  // Game-specific configuration
  late final int _numberOfRounds;
  late final Duration _stimulusInterval;
  late final Duration _responseWindow;
  late final int _minimumHeartRateIncrease;
  
  // Game state tracking
  int _currentRound = 0;
  bool _stimulusActive = false;
  DateTime? _stimulusTime;
  Timer? _stimulusTimer;
  Timer? _responseTimer;
  
  // Player response tracking
  final Map<String, List<StimulusResponse>> _playerResponses = {};
  final Map<String, int> _roundScores = {};
  final Map<String, int> _totalScores = {};

  InstantResponseGame({
    required String sessionId,
    required GameConfig config,
  }) : super(sessionId: sessionId, config: config);

  @override
  Future<void> _performGameSpecificInitialization(GameConfig config) async {
    // Extract game-specific parameters
    _numberOfRounds = config.parameters['rounds'] as int? ?? 5;
    _stimulusInterval = Duration(
      seconds: config.parameters['stimulusIntervalSeconds'] as int? ?? 30,
    );
    _responseWindow = Duration(
      seconds: config.parameters['responseWindowSeconds'] as int? ?? 10,
    );
    _minimumHeartRateIncrease = config.parameters['minHeartRateIncrease'] as int? ?? 10;
    
    // Validate parameters
    if (_numberOfRounds < 1 || _numberOfRounds > 20) {
      throw GameException('Number of rounds must be between 1 and 20, got $_numberOfRounds');
    }
    if (_stimulusInterval.inSeconds < 15) {
      throw GameException('Stimulus interval must be at least 15 seconds');
    }
    if (_responseWindow.inSeconds < 5) {
      throw GameException('Response window must be at least 5 seconds');
    }
    
    // Initialize player tracking
    for (final player in players) {
      _playerResponses[player.playerId] = [];
      _roundScores[player.playerId] = 0;
      _totalScores[player.playerId] = 0;
    }
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'gameType': 'instantResponse',
        'rounds': _numberOfRounds,
        'stimulusInterval': _stimulusInterval.inSeconds,
        'responseWindow': _responseWindow.inSeconds,
        'minHeartRateIncrease': _minimumHeartRateIncrease,
      },
    ));
  }

  @override
  Future<void> _performGameSpecificStart() async {
    _currentRound = 0;
    await _startNextRound();
  }

  @override
  void _processGameSpecificHeartRate(String playerId, int bpm) {
    if (!_stimulusActive || _stimulusTime == null) {
      // Store baseline heart rate before stimulus
      _updatePlayerBaseline(playerId, bpm);
      return;
    }
    
    // Process heart rate change during response window
    _processHeartRateResponse(playerId, bpm);
  }

  @override
  Future<void> _performGameSpecificStop() async {
    _stimulusTimer?.cancel();
    _responseTimer?.cancel();
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'gameEnded': true,
        'completedRounds': _currentRound,
        'totalRounds': _numberOfRounds,
      },
    ));
  }

  @override
  List<PlayerScore> _calculateCurrentScores() {
    final scores = <PlayerScore>[];
    
    for (final playerId in _totalScores.keys) {
      final totalScore = _totalScores[playerId]!.toDouble();
      scores.add(PlayerScore(
        playerId: playerId,
        score: totalScore,
        rank: 0, // Will be calculated after sorting
        metrics: {
          'totalScore': totalScore,
          'roundScore': _roundScores[playerId] ?? 0,
          'responsesCount': _playerResponses[playerId]?.length ?? 0,
          'currentRound': _currentRound,
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
      'gameType': 'instantResponse',
      'completedRounds': _currentRound,
      'totalRounds': _numberOfRounds,
      'averageResponseTime': _calculateAverageResponseTime(),
      'bestResponse': _findBestResponse(),
      'stimulusInterval': _stimulusInterval.inSeconds,
      'responseWindow': _responseWindow.inSeconds,
      'playerResponses': _playerResponses.map(
        (playerId, responses) => MapEntry(
          playerId, 
          responses.map((r) => r.toJson()).toList(),
        ),
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

  Future<void> _startNextRound() async {
    if (_currentRound >= _numberOfRounds) {
      await stop();
      return;
    }
    
    _currentRound++;
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'roundStarted': _currentRound,
        'totalRounds': _numberOfRounds,
        'nextStimulusIn': _stimulusInterval.inSeconds,
      },
    ));
    
    // Wait for stimulus interval, then trigger stimulus
    _stimulusTimer = Timer(_stimulusInterval, _triggerStimulus);
  }

  void _triggerStimulus() {
    _stimulusActive = true;
    _stimulusTime = DateTime.now();
    
    // Clear round scores for new round
    _roundScores.clear();
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'stimulusTriggered': true,
        'round': _currentRound,
        'responseWindow': _responseWindow.inSeconds,
        'stimulusTime': _stimulusTime!.toIso8601String(),
      },
    ));
    
    // Start response window timer
    _responseTimer = Timer(_responseWindow, _endResponseWindow);
  }

  void _endResponseWindow() {
    _stimulusActive = false;
    
    // Calculate round results
    _calculateRoundResults();
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'responseWindowEnded': true,
        'round': _currentRound,
        'roundScores': Map.from(_roundScores),
        'totalScores': Map.from(_totalScores),
      },
    ));
    
    // Start next round after a brief pause
    Timer(const Duration(seconds: 3), _startNextRound);
  }

  void _updatePlayerBaseline(String playerId, int bpm) {
    if (!_playerResponses.containsKey(playerId)) {
      _playerResponses[playerId] = [];
    }
    
    // Update baseline only if we don't have a recent one
    final responses = _playerResponses[playerId]!;
    if (responses.isEmpty || 
        DateTime.now().difference(responses.last.timestamp).inSeconds > 5) {
      // Store as baseline data point (not a response to stimulus)
      responses.add(StimulusResponse(
        playerId: playerId,
        baselineHeartRate: bpm,
        responseHeartRate: bpm,
        responseTime: Duration.zero,
        heartRateIncrease: 0,
        isValidResponse: false,
        timestamp: DateTime.now(),
        round: _currentRound,
      ));
    }
  }

  void _processHeartRateResponse(String playerId, int bpm) {
    if (_stimulusTime == null) return;
    
    final responseTime = DateTime.now().difference(_stimulusTime!);
    
    // Get the most recent baseline for this player
    final playerResponses = _playerResponses[playerId] ?? [];
    if (playerResponses.isEmpty) return;
    
    final baseline = playerResponses.last.baselineHeartRate;
    final heartRateIncrease = bpm - baseline;
    
    // Check if this is a valid response
    final isValidResponse = heartRateIncrease >= _minimumHeartRateIncrease;
    
    // Only record the first significant response per player per round
    final hasResponseThisRound = playerResponses
        .where((r) => r.round == _currentRound && r.isValidResponse)
        .isNotEmpty;
    
    if (isValidResponse && !hasResponseThisRound) {
      final response = StimulusResponse(
        playerId: playerId,
        baselineHeartRate: baseline,
        responseHeartRate: bpm,
        responseTime: responseTime,
        heartRateIncrease: heartRateIncrease,
        isValidResponse: true,
        timestamp: DateTime.now(),
        round: _currentRound,
      );
      
      playerResponses.add(response);
      
      _broadcastUpdate(GameUpdate(
        type: GameUpdateType.heartRateUpdate,
        timestamp: DateTime.now(),
        data: {
          'playerId': playerId,
          'heartRate': bpm,
          'response': response.toJson(),
        },
      ));
    }
  }

  void _calculateRoundResults() {
    final validResponses = <String, StimulusResponse>{};
    
    // Find the fastest valid response for each player this round
    for (final playerId in _playerResponses.keys) {
      final responses = _playerResponses[playerId]!
          .where((r) => r.round == _currentRound && r.isValidResponse)
          .toList();
      
      if (responses.isNotEmpty) {
        // Sort by response time (fastest first)
        responses.sort((a, b) => a.responseTime.compareTo(b.responseTime));
        validResponses[playerId] = responses.first;
      }
    }
    
    if (validResponses.isEmpty) {
      // No valid responses this round
      return;
    }
    
    // Award points based on response speed ranking
    final sortedResponses = validResponses.entries.toList()
      ..sort((a, b) => a.value.responseTime.compareTo(b.value.responseTime));
    
    for (int i = 0; i < sortedResponses.length; i++) {
      final playerId = sortedResponses[i].key;
      final response = sortedResponses[i].value;
      
      // Award points: first place gets most points, decreasing for lower ranks
      int points = (sortedResponses.length - i) * 100;
      
      // Bonus points for faster response and higher heart rate increase
      final speedBonus = max(0, 50 - (response.responseTime.inSeconds * 5));
      final intensityBonus = min(50, response.heartRateIncrease - _minimumHeartRateIncrease);
      
      final totalRoundPoints = points + speedBonus + intensityBonus;
      
      _roundScores[playerId] = totalRoundPoints;
      _totalScores[playerId] = (_totalScores[playerId] ?? 0) + totalRoundPoints;
    }
  }

  double _calculateAverageResponseTime() {
    final allResponses = _playerResponses.values
        .expand((responses) => responses)
        .where((r) => r.isValidResponse)
        .toList();
    
    if (allResponses.isEmpty) return 0.0;
    
    final totalTime = allResponses
        .map((r) => r.responseTime.inMilliseconds)
        .reduce((a, b) => a + b);
    
    return totalTime / allResponses.length;
  }

  Map<String, dynamic>? _findBestResponse() {
    StimulusResponse? bestResponse;
    
    for (final responses in _playerResponses.values) {
      for (final response in responses.where((r) => r.isValidResponse)) {
        if (bestResponse == null || 
            response.responseTime.compareTo(bestResponse.responseTime) < 0) {
          bestResponse = response;
        }
      }
    }
    
    return bestResponse?.toJson();
  }
}

/// Data class representing a player's response to a stimulus
class StimulusResponse {
  final String playerId;
  final int baselineHeartRate;
  final int responseHeartRate;
  final Duration responseTime;
  final int heartRateIncrease;
  final bool isValidResponse;
  final DateTime timestamp;
  final int round;

  const StimulusResponse({
    required this.playerId,
    required this.baselineHeartRate,
    required this.responseHeartRate,
    required this.responseTime,
    required this.heartRateIncrease,
    required this.isValidResponse,
    required this.timestamp,
    required this.round,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'baselineHeartRate': baselineHeartRate,
      'responseHeartRate': responseHeartRate,
      'responseTimeMs': responseTime.inMilliseconds,
      'heartRateIncrease': heartRateIncrease,
      'isValidResponse': isValidResponse,
      'timestamp': timestamp.toIso8601String(),
      'round': round,
    };
  }
}