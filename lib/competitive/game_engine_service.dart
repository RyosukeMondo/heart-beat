import 'dart:async';
import 'dart:math';

import 'networking_service.dart';
import 'models/models.dart';
import 'games/base_game.dart';
import 'games/instant_response_game.dart';
import 'games/resilience_game.dart';
import 'games/endurance_game.dart';

/// Game Engine Service Implementation
/// 
/// Orchestrates competitive gaming functionality by coordinating between
/// networking, game logic, and session management. Provides a unified
/// interface for managing multiplayer heart rate gaming sessions.
class GameEngineService {
  final NetworkingService _networkingService;
  
  // Stream controllers for game state management
  final StreamController<GameState> _gameStateController = StreamController<GameState>.broadcast();
  final StreamController<List<PlayerScore>> _scoresController = StreamController<List<PlayerScore>>.broadcast();
  final StreamController<GameUpdate> _gameUpdatesController = StreamController<GameUpdate>.broadcast();
  final StreamController<GameResult?> _gameResultController = StreamController<GameResult?>.broadcast();
  
  // Game state tracking
  BaseGame? _currentGame;
  GameSession? _currentSession;
  GameState _currentGameState = GameState.initializing;
  String? _currentPlayerId;
  bool _isHost = false;
  
  // Subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  GameEngineService({NetworkingService? networkingService})
      : _networkingService = networkingService ?? NetworkingService() {
    _initializeServiceListeners();
  }

  // Public getters
  GameState get currentGameState => _currentGameState;
  BaseGame? get currentGame => _currentGame;
  GameSession? get currentSession => _currentSession;
  bool get isHost => _isHost;
  bool get hasActiveGame => _currentGame != null;
  bool get isGameActive => _currentGameState == GameState.active;
  
  /// Stream of game state changes
  Stream<GameState> get gameStateStream => _gameStateController.stream;
  
  /// Stream of current player scores
  Stream<List<PlayerScore>> get scoresStream => _scoresController.stream;
  
  /// Stream of game updates (events, notifications, etc.)
  Stream<GameUpdate> get gameUpdatesStream => _gameUpdatesController.stream;
  
  /// Stream of game results (when games complete)
  Stream<GameResult?> get gameResultStream => _gameResultController.stream;
  
  /// Stream of connected players
  Stream<List<PlayerData>> get playersStream => _networkingService.playersStream;
  
  /// Stream of session information
  Stream<GameSession?> get sessionStream => _networkingService.sessionStream;
  
  /// Stream of networking connection state
  Stream<NetworkingConnectionState> get connectionStateStream => _networkingService.connectionStateStream;

  /// Initialize the game engine service
  Future<void> initialize() async {
    await _networkingService.initialize();
    _updateGameState(GameState.ready);
  }

  // Session Management

  /// Create a new competitive gaming session
  Future<GameSession> createSession({
    required GameType gameType,
    required GameConfig config,
    required String hostPlayerId,
    required String hostPlayerName,
    int maxPlayers = 8,
    bool isPublic = false,
    String? sessionName,
  }) async {
    try {
      final session = await _networkingService.createSession(
        gameType: gameType,
        config: config,
        hostPlayerId: hostPlayerId,
        hostPlayerName: hostPlayerName,
        maxPlayers: maxPlayers,
        isPublic: isPublic,
        sessionName: sessionName,
      );
      
      _currentSession = session;
      _currentPlayerId = hostPlayerId;
      _isHost = true;
      
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.gameStateChanged,
        timestamp: DateTime.now(),
        data: {
          'action': 'sessionCreated',
          'sessionId': session.id,
          'sessionCode': session.id, // Assuming session has a join code
          'gameType': gameType.name,
          'isHost': true,
        },
      ));
      
      return session;
    } catch (e) {
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.error,
        timestamp: DateTime.now(),
        data: {
          'action': 'createSessionFailed',
          'error': e.toString(),
        },
      ));
      rethrow;
    }
  }

  /// Join an existing competitive gaming session
  Future<GameSession> joinSession({
    required String sessionCode,
    required String playerId,
    required String playerName,
  }) async {
    try {
      final session = await _networkingService.joinSession(
        sessionCode: sessionCode,
        playerId: playerId,
        playerName: playerName,
      );
      
      _currentSession = session;
      _currentPlayerId = playerId;
      _isHost = false;
      
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.gameStateChanged,
        timestamp: DateTime.now(),
        data: {
          'action': 'sessionJoined',
          'sessionId': session.id,
          'gameType': session.gameType.name,
          'isHost': false,
        },
      ));
      
      return session;
    } catch (e) {
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.error,
        timestamp: DateTime.now(),
        data: {
          'action': 'joinSessionFailed',
          'error': e.toString(),
        },
      ));
      rethrow;
    }
  }

  /// Leave the current session
  Future<void> leaveSession() async {
    if (_currentGame != null && _currentGameState == GameState.active) {
      await stopGame();
    }
    
    await _networkingService.leaveSession();
    
    _currentSession = null;
    _currentPlayerId = null;
    _isHost = false;
    _currentGame = null;
    
    _updateGameState(GameState.ready);
    
    _broadcastGameUpdate(GameUpdate(
      type: GameUpdateType.gameStateChanged,
      timestamp: DateTime.now(),
      data: {
        'action': 'sessionLeft',
      },
    ));
  }

  // Game Management

  /// Start a competitive game in the current session
  Future<void> startGame() async {
    if (!_isHost) {
      throw GameEngineException('Only the session host can start games');
    }
    
    if (_currentSession == null) {
      throw GameEngineException('No active session to start game in');
    }
    
    try {
      // Create game instance based on session type
      _currentGame = _createGameInstance(_currentSession!);
      
      // Initialize the game
      await _currentGame!.initialize(_currentSession!.config);
      
      // Set up game event listeners
      _setupGameListeners();
      
      // Notify networking service to start the game
      await _networkingService.startGame();
      
      // Start the actual game
      await _currentGame!.start();
      
      _updateGameState(GameState.active);
      
    } catch (e) {
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.error,
        timestamp: DateTime.now(),
        data: {
          'action': 'startGameFailed',
          'error': e.toString(),
        },
      ));
      rethrow;
    }
  }

  /// Stop the current game
  Future<void> stopGame() async {
    if (!_isHost) {
      throw GameEngineException('Only the session host can stop games');
    }
    
    if (_currentGame == null) {
      return; // No active game to stop
    }
    
    try {
      // Stop the game and get results
      final result = await _currentGame!.stop();
      
      // Notify networking service
      await _networkingService.stopGame();
      
      // Update state
      _updateGameState(GameState.completed);
      
      // Broadcast results
      _gameResultController.add(result);
      
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.gameEnded,
        timestamp: DateTime.now(),
        data: {
          'action': 'gameStopped',
          'result': result.toJson(),
        },
      ));
      
      // Clean up game
      _currentGame?.dispose();
      _currentGame = null;
      
    } catch (e) {
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.error,
        timestamp: DateTime.now(),
        data: {
          'action': 'stopGameFailed',
          'error': e.toString(),
        },
      ));
      rethrow;
    }
  }

  /// Pause the current game
  Future<void> pauseGame() async {
    if (!_isHost) {
      throw GameEngineException('Only the session host can pause games');
    }
    
    if (_currentGame == null || _currentGameState != GameState.active) {
      return;
    }
    
    try {
      // Notify networking service
      await _networkingService.stopGame(pause: true);
      
      _updateGameState(GameState.paused);
      
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.gameStateChanged,
        timestamp: DateTime.now(),
        data: {
          'action': 'gamePaused',
        },
      ));
      
    } catch (e) {
      _broadcastGameUpdate(GameUpdate(
        type: GameUpdateType.error,
        timestamp: DateTime.now(),
        data: {
          'action': 'pauseGameFailed',
          'error': e.toString(),
        },
      ));
      rethrow;
    }
  }

  // Heart Rate Processing

  /// Process heart rate data for the current player
  Future<void> processPlayerHeartRate(int heartRate) async {
    if (_currentPlayerId == null) {
      return; // Not connected to a session
    }
    
    // Send heart rate to networking service for distribution
    await _networkingService.broadcastHeartRate(heartRate: heartRate);
    
    // Process heart rate in current game if active
    if (_currentGame != null && _currentGameState == GameState.active) {
      _currentGame!.processHeartRateUpdate(_currentPlayerId!, heartRate);
    }
  }

  /// Update player status
  Future<void> updatePlayerStatus(PlayerStatus status, {String? statusMessage}) async {
    if (_currentPlayerId == null) {
      return;
    }
    
    await _networkingService.updatePlayerStatus(
      status: status,
      statusMessage: statusMessage,
    );
  }

  // Game Type Creation

  /// Create game instance based on game type
  BaseGame _createGameInstance(GameSession session) {
    final sessionId = session.id;
    final config = session.config;
    
    switch (session.gameType) {
      case GameType.instantResponse:
        return InstantResponseGame(sessionId: sessionId, config: config);
      case GameType.resilience:
        return ResilienceGame(sessionId: sessionId, config: config);
      case GameType.endurance:
        return EnduranceGame(sessionId: sessionId, config: config);
      default:
        throw GameEngineException('Unsupported game type: ${session.gameType}');
    }
  }

  // Private helper methods

  void _initializeServiceListeners() {
    // Listen to networking events
    _subscriptions.add(
      _networkingService.eventsStream.listen(_handleNetworkingEvent)
    );
    
    // Listen to heart rate events from other players
    _subscriptions.add(
      _networkingService.heartRateEventsStream.listen(_handleHeartRateEvent)
    );
    
    // Listen to game events
    _subscriptions.add(
      _networkingService.gameEventsStream.listen(_handleGameEvent)
    );
    
    // Listen to session changes
    _subscriptions.add(
      _networkingService.sessionStream.listen(_handleSessionChange)
    );
  }

  void _setupGameListeners() {
    if (_currentGame == null) return;
    
    // Listen to game updates
    _subscriptions.add(
      _currentGame!.gameUpdatesStream.listen(_handleGameUpdate)
    );
    
    // Listen to score updates
    _subscriptions.add(
      _currentGame!.scoresStream.listen(_handleScoreUpdate)
    );
  }

  void _handleNetworkingEvent(NetworkingEvent event) {
    _broadcastGameUpdate(GameUpdate(
      type: GameUpdateType.values.byName(event.type.name),
      timestamp: event.timestamp,
      data: {
        'networkingEvent': event.toJson(),
        ...event.data,
      },
    ));
  }

  void _handleHeartRateEvent(NetworkingEvent event) {
    if (_currentGame != null && event.playerId != null && event.playerId != _currentPlayerId) {
      // Process heart rate from other players
      final heartRate = event.data['heartRate'] as int?;
      if (heartRate != null) {
        _currentGame!.processHeartRateUpdate(event.playerId!, heartRate);
      }
    }
  }

  void _handleGameEvent(NetworkingEvent event) {
    // Handle game-specific events from networking
    _broadcastGameUpdate(GameUpdate(
      type: GameUpdateType.gameEvent,
      timestamp: event.timestamp,
      data: event.data,
    ));
  }

  void _handleSessionChange(GameSession? session) {
    _currentSession = session;
    
    if (session == null) {
      // Session ended or left
      _currentGame?.dispose();
      _currentGame = null;
      _updateGameState(GameState.ready);
    }
  }

  void _handleGameUpdate(GameUpdate update) {
    _broadcastGameUpdate(update);
  }

  void _handleScoreUpdate(List<PlayerScore> scores) {
    _scoresController.add(scores);
  }

  void _updateGameState(GameState newState) {
    if (_currentGameState != newState) {
      _currentGameState = newState;
      _gameStateController.add(newState);
    }
  }

  void _broadcastGameUpdate(GameUpdate update) {
    if (!_gameUpdatesController.isClosed) {
      _gameUpdatesController.add(update);
    }
  }

  // Utility methods

  /// Get available game types
  static List<GameType> getAvailableGameTypes() {
    return GameType.values;
  }

  /// Get default configuration for a game type
  static GameConfig getDefaultConfig(GameType gameType) {
    switch (gameType) {
      case GameType.instantResponse:
        return GameConfig(
          duration: const Duration(minutes: 10),
          difficulty: 3,
          parameters: {
            'rounds': 5,
            'stimulusIntervalSeconds': 30,
            'responseWindowSeconds': 10,
            'minHeartRateIncrease': 10,
          },
        );
      case GameType.resilience:
        return GameConfig(
          duration: const Duration(minutes: 15),
          difficulty: 3,
          parameters: {
            'zoneWidth': 20,
            'maxVariability': 15.0,
            'measurementWindowSeconds': 10,
            'phases': [
              {
                'name': 'Warm-up',
                'duration': 60000,
                'description': 'Establish baseline',
                'targetIntensityMultiplier': 1.0,
                'difficultyMultiplier': 1.0,
              },
              {
                'name': 'Light Stress',
                'duration': 120000,
                'description': 'Light stress phase',
                'targetIntensityMultiplier': 1.1,
                'difficultyMultiplier': 1.2,
              },
              {
                'name': 'Moderate Stress',
                'duration': 180000,
                'description': 'Moderate stress phase',
                'targetIntensityMultiplier': 1.2,
                'difficultyMultiplier': 1.5,
              },
            ],
          },
        );
      case GameType.endurance:
        return GameConfig(
          duration: const Duration(minutes: 20),
          difficulty: 3,
          parameters: {
            'eliminationGraceSeconds': 30,
            'targetZoneMin': 120,
            'targetZoneMax': 160,
            'eliminationThreshold': 100,
            'eliminationEnabled': true,
            'pointsPerSecond': 10,
          },
        );
      default:
        return GameConfig(
          duration: const Duration(minutes: 10),
          difficulty: 3,
        );
    }
  }

  /// Validate game configuration
  static bool isValidConfig(GameType gameType, GameConfig config) {
    try {
      // Basic validation
      if (config.duration.inSeconds <= 0) return false;
      if (config.difficulty < 1 || config.difficulty > 5) return false;
      
      // Game-specific validation
      switch (gameType) {
        case GameType.instantResponse:
          final rounds = config.parameters['rounds'] as int?;
          if (rounds != null && (rounds < 1 || rounds > 20)) return false;
          break;
        case GameType.resilience:
          final maxVariability = config.parameters['maxVariability'] as double?;
          if (maxVariability != null && (maxVariability < 5.0 || maxVariability > 30.0)) return false;
          break;
        case GameType.endurance:
          final minZone = config.parameters['targetZoneMin'] as int?;
          final maxZone = config.parameters['targetZoneMax'] as int?;
          if (minZone != null && maxZone != null && minZone >= maxZone) return false;
          break;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Stop current game if active
    if (_currentGame != null) {
      _currentGame!.dispose();
      _currentGame = null;
    }
    
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // Close stream controllers
    await _gameStateController.close();
    await _scoresController.close();
    await _gameUpdatesController.close();
    await _gameResultController.close();
    
    // Dispose networking service
    await _networkingService.dispose();
  }
}

/// Exception thrown by game engine operations
class GameEngineException implements Exception {
  final String message;

  const GameEngineException(this.message);

  @override
  String toString() => 'GameEngineException: $message';
}