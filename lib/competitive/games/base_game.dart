import 'dart:async';
import 'dart:math';

/// Base abstract class for all competitive game types
/// 
/// Provides the foundation for implementing heart rate-based competitive games
/// including timing infrastructure, player management, and result calculation.
abstract class BaseGame {
  /// Game session identifier
  final String sessionId;
  
  /// Game configuration parameters
  final GameConfig config;
  
  /// Stream controller for game updates
  final StreamController<GameUpdate> _gameUpdatesController = StreamController<GameUpdate>.broadcast();
  
  /// Stream controller for player scores
  final StreamController<List<PlayerScore>> _scoresController = StreamController<List<PlayerScore>>.broadcast();
  
  /// Game timing infrastructure
  Timer? _gameTimer;
  DateTime? _gameStartTime;
  Duration _gameDuration = Duration.zero;
  
  /// Player management
  final Map<String, PlayerGameData> _players = {};
  
  /// Game state tracking
  GameState _currentState = GameState.initializing;
  
  BaseGame({
    required this.sessionId,
    required this.config,
  });

  // Public getters
  GameState get currentState => _currentState;
  Duration get gameDuration => _gameDuration;
  DateTime? get gameStartTime => _gameStartTime;
  List<PlayerGameData> get players => _players.values.toList();
  
  /// Stream of game updates for UI consumption
  Stream<GameUpdate> get gameUpdatesStream => _gameUpdatesController.stream;
  
  /// Stream of current player scores
  Stream<List<PlayerScore>> get scoresStream => _scoresController.stream;

  /// Initialize the game with specific configuration
  /// 
  /// Must be called before starting the game. Implementations should
  /// set up game-specific state and validate configuration parameters.
  Future<void> initialize(GameConfig gameConfig) async {
    if (_currentState != GameState.initializing) {
      throw GameException('Cannot initialize game in state $_currentState');
    }
    
    try {
      await _performGameSpecificInitialization(gameConfig);
      _updateGameState(GameState.ready);
      
      _broadcastUpdate(GameUpdate(
        type: GameUpdateType.gameStateChanged,
        timestamp: DateTime.now(),
        data: {'state': GameState.ready.name},
      ));
      
    } catch (e) {
      _updateGameState(GameState.error);
      _broadcastUpdate(GameUpdate(
        type: GameUpdateType.error,
        timestamp: DateTime.now(),
        data: {'error': e.toString()},
      ));
      rethrow;
    }
  }

  /// Process heart rate update from a specific player
  /// 
  /// This method is called whenever a player's heart rate data is received.
  /// Implementations should process the data according to game-specific rules.
  void processHeartRateUpdate(String playerId, int bpm) {
    if (_currentState != GameState.active) {
      return; // Ignore heart rate updates when game is not active
    }
    
    // Validate heart rate using patterns from HeartRateParser
    if (!_isValidHeartRate(bpm)) {
      _broadcastUpdate(GameUpdate(
        type: GameUpdateType.error,
        timestamp: DateTime.now(),
        data: {
          'playerId': playerId,
          'error': 'Invalid heart rate: $bpm BPM',
          'validRange': '20-300 BPM'
        },
      ));
      return;
    }
    
    // Update player data
    if (_players.containsKey(playerId)) {
      _players[playerId]!.updateHeartRate(bpm);
    } else {
      _players[playerId] = PlayerGameData(
        playerId: playerId,
        currentHeartRate: bpm,
      );
    }
    
    // Process the heart rate update in game-specific logic
    _processGameSpecificHeartRate(playerId, bpm);
    
    // Broadcast heart rate update
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.heartRateUpdate,
      timestamp: DateTime.now(),
      data: {
        'playerId': playerId,
        'heartRate': bpm,
      },
    ));
    
    // Update and broadcast current scores
    _updateScores();
  }

  /// Start the game with all connected players
  Future<void> start() async {
    if (_currentState != GameState.ready) {
      throw GameException('Cannot start game in state $_currentState');
    }
    
    _gameStartTime = DateTime.now();
    _updateGameState(GameState.active);
    
    // Start game timer
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), _onGameTick);
    
    // Perform game-specific start logic
    await _performGameSpecificStart();
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameStarted,
      timestamp: DateTime.now(),
      data: {
        'startTime': _gameStartTime!.toIso8601String(),
        'duration': config.duration.inSeconds,
        'playerCount': _players.length,
      },
    ));
  }

  /// Stop the game and calculate final results
  Future<GameResult> stop() async {
    if (_currentState != GameState.active) {
      throw GameException('Cannot stop game in state $_currentState');
    }
    
    // Stop the game timer
    _gameTimer?.cancel();
    _gameTimer = null;
    
    _updateGameState(GameState.completed);
    
    // Perform game-specific cleanup
    await _performGameSpecificStop();
    
    // Calculate final results
    final result = await calculateResults();
    
    _broadcastUpdate(GameUpdate(
      type: GameUpdateType.gameEnded,
      timestamp: DateTime.now(),
      data: {
        'result': result.toJson(),
        'duration': _gameDuration.inSeconds,
      },
    ));
    
    return result;
  }

  /// Calculate game results based on player performance
  /// 
  /// Must be implemented by concrete game types to define win/lose logic
  Future<GameResult> calculateResults();

  /// Dispose resources and cleanup
  void dispose() {
    _gameTimer?.cancel();
    _gameUpdatesController.close();
    _scoresController.close();
  }

  // Protected methods for subclass implementation

  /// Game-specific initialization logic
  /// 
  /// Called during [initialize] to set up game-type-specific state
  Future<void> _performGameSpecificInitialization(GameConfig config);

  /// Process heart rate data according to game rules
  /// 
  /// Called whenever a valid heart rate update is received
  void _processGameSpecificHeartRate(String playerId, int bpm);

  /// Game-specific start logic
  /// 
  /// Called when the game transitions to active state
  Future<void> _performGameSpecificStart();

  /// Game-specific stop logic
  /// 
  /// Called when the game is being stopped, before result calculation
  Future<void> _performGameSpecificStop();

  /// Calculate current scores for all players
  /// 
  /// Should be implemented by concrete games to define scoring logic
  List<PlayerScore> _calculateCurrentScores();

  // Private helper methods

  void _updateGameState(GameState newState) {
    _currentState = newState;
  }

  void _broadcastUpdate(GameUpdate update) {
    if (!_gameUpdatesController.isClosed) {
      _gameUpdatesController.add(update);
    }
  }

  void _updateScores() {
    final scores = _calculateCurrentScores();
    if (!_scoresController.isClosed) {
      _scoresController.add(scores);
    }
  }

  void _onGameTick(Timer timer) {
    if (_gameStartTime != null) {
      _gameDuration = DateTime.now().difference(_gameStartTime!);
      
      // Check if game duration has been exceeded
      if (_gameDuration >= config.duration) {
        stop();
        return;
      }
      
      // Broadcast game tick for UI updates
      _broadcastUpdate(GameUpdate(
        type: GameUpdateType.gameTick,
        timestamp: DateTime.now(),
        data: {
          'elapsed': _gameDuration.inMilliseconds,
          'remaining': (config.duration - _gameDuration).inMilliseconds,
        },
      ));
    }
  }

  /// Validate heart rate value using patterns from HeartRateParser
  bool _isValidHeartRate(int bpm) {
    return bpm >= 20 && bpm <= 300;
  }
}

/// Game configuration parameters
class GameConfig {
  /// Game duration
  final Duration duration;
  
  /// Difficulty level (1-5)
  final int difficulty;
  
  /// Game-specific parameters
  final Map<String, dynamic> parameters;

  const GameConfig({
    required this.duration,
    this.difficulty = 3,
    this.parameters = const {},
  });

  GameConfig copyWith({
    Duration? duration,
    int? difficulty,
    Map<String, dynamic>? parameters,
  }) {
    return GameConfig(
      duration: duration ?? this.duration,
      difficulty: difficulty ?? this.difficulty,
      parameters: parameters ?? this.parameters,
    );
  }
}

/// Player data specific to game sessions
class PlayerGameData {
  final String playerId;
  int currentHeartRate;
  DateTime lastHeartRateUpdate;
  final List<HeartRatePoint> heartRateHistory = [];

  PlayerGameData({
    required this.playerId,
    required this.currentHeartRate,
    DateTime? lastUpdate,
  }) : lastHeartRateUpdate = lastUpdate ?? DateTime.now();

  void updateHeartRate(int bpm) {
    currentHeartRate = bpm;
    lastHeartRateUpdate = DateTime.now();
    heartRateHistory.add(HeartRatePoint(bpm, lastHeartRateUpdate));
    
    // Keep only recent history to prevent memory issues
    if (heartRateHistory.length > 1000) {
      heartRateHistory.removeRange(0, heartRateHistory.length - 1000);
    }
  }

  /// Get heart rate changes over specified duration
  List<int> getHeartRateChanges(Duration period) {
    final cutoff = DateTime.now().subtract(period);
    return heartRateHistory
        .where((point) => point.timestamp.isAfter(cutoff))
        .map((point) => point.bpm)
        .toList();
  }

  /// Calculate average heart rate over specified duration
  double getAverageHeartRate(Duration period) {
    final changes = getHeartRateChanges(period);
    if (changes.isEmpty) return currentHeartRate.toDouble();
    return changes.reduce((a, b) => a + b) / changes.length;
  }
}

/// Point in time heart rate measurement
class HeartRatePoint {
  final int bpm;
  final DateTime timestamp;

  HeartRatePoint(this.bpm, this.timestamp);
}

/// Player score information
class PlayerScore {
  final String playerId;
  final double score;
  final int rank;
  final Map<String, dynamic> metrics;

  const PlayerScore({
    required this.playerId,
    required this.score,
    required this.rank,
    this.metrics = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'score': score,
      'rank': rank,
      'metrics': metrics,
    };
  }
}

/// Game result with winner and detailed metrics
class GameResult {
  final String sessionId;
  final List<PlayerScore> scores;
  final PlayerScore winner;
  final Duration gameDuration;
  final DateTime completedAt;
  final Map<String, dynamic> gameMetrics;

  const GameResult({
    required this.sessionId,
    required this.scores,
    required this.winner,
    required this.gameDuration,
    required this.completedAt,
    required this.gameMetrics,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'scores': scores.map((s) => s.toJson()).toList(),
      'winner': winner.toJson(),
      'gameDuration': gameDuration.inSeconds,
      'completedAt': completedAt.toIso8601String(),
      'gameMetrics': gameMetrics,
    };
  }
}

/// Game state enumeration
enum GameState {
  initializing,
  ready,
  active,
  paused,
  completed,
  error,
}

/// Game update types for real-time communication
enum GameUpdateType {
  gameStateChanged,
  gameStarted,
  gameEnded,
  heartRateUpdate,
  playerJoined,
  playerLeft,
  gameTick,
  error,
}

/// Game update message
class GameUpdate {
  final GameUpdateType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const GameUpdate({
    required this.type,
    required this.timestamp,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
    };
  }
}

/// Exception thrown by game operations
class GameException implements Exception {
  final String message;

  const GameException(this.message);

  @override
  String toString() => 'GameException: $message';
}