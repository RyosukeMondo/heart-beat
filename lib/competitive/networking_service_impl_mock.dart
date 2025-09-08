/// Mock implementation of NetworkingService for local development and testing
/// 
/// This implementation simulates multiplayer networking functionality using
/// local Stream controllers and in-memory data structures. It enables
/// development and testing without requiring actual network infrastructure.

import 'dart:async';
import 'dart:math';

import 'networking_service.dart';
import 'models/models.dart';

/// Mock networking service for local development and testing
/// 
/// Simulates real networking behavior using Stream controllers and local state.
/// Supports multiple simulated players and realistic event timing.
class MockNetworkingService implements NetworkingService {
  // Stream controllers for broadcasting events
  final StreamController<NetworkingConnectionState> _connectionStateController =
      StreamController<NetworkingConnectionState>.broadcast();
  final StreamController<NetworkingEvent> _eventsController =
      StreamController<NetworkingEvent>.broadcast();
  final StreamController<List<PlayerData>> _playersController =
      StreamController<List<PlayerData>>.broadcast();
  final StreamController<GameSession?> _sessionController =
      StreamController<GameSession?>.broadcast();

  // Internal state
  NetworkingConnectionState _connectionState = NetworkingConnectionState.idle;
  GameSession? _currentSession;
  PlayerData? _currentPlayer;
  final Map<String, PlayerData> _players = {};
  final List<NetworkingEvent> _eventHistory = [];
  final Random _random = Random();

  // Simulated sessions (shared across instances for multi-player simulation)
  static final Map<String, GameSession> _globalSessions = {};
  static final Map<String, Map<String, PlayerData>> _sessionPlayers = {};
  static final Map<String, List<NetworkingEvent>> _sessionEvents = {};

  @override
  Stream<NetworkingConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Stream<NetworkingEvent> get eventsStream => _eventsController.stream;

  @override
  Stream<List<PlayerData>> get playersStream => _playersController.stream;

  @override
  Stream<GameSession?> get sessionStream => _sessionController.stream;

  @override
  NetworkingConnectionState get connectionState => _connectionState;

  @override
  GameSession? get currentSession => _currentSession;

  @override
  List<PlayerData> get connectedPlayers => _players.values.toList();

  @override
  PlayerData? get currentPlayer => _currentPlayer;

  @override
  bool get isSupported => true; // Mock is always supported

  @override
  Future<void> initialize() async {
    // Simulate initialization delay
    await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));
    
    print('MockNetworkingService: Initialized successfully');
  }

  @override
  Future<GameSession> createSession({
    required GameType gameType,
    required GameConfig config,
    required String hostPlayerId,
    required String hostPlayerName,
    int maxPlayers = 8,
    bool isPublic = false,
    String? sessionName,
  }) async {
    _updateConnectionState(NetworkingConnectionState.connecting);
    
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 300 + _random.nextInt(500)));

    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final joinCode = generateSessionCode();

    final session = GameSession(
      id: sessionId,
      hostId: hostPlayerId,
      playerIds: [hostPlayerId],
      gameType: gameType,
      state: GameState.lobby,
      createdAt: DateTime.now(),
      config: config,
      maxPlayers: maxPlayers,
      isPublic: isPublic,
      sessionName: sessionName,
      joinCode: joinCode,
    );

    // Store in global sessions
    _globalSessions[sessionId] = session;
    _sessionPlayers[sessionId] = {};
    _sessionEvents[sessionId] = [];

    // Create host player
    final hostPlayer = PlayerData(
      id: hostPlayerId,
      username: hostPlayerName,
      currentHeartRate: 70 + _random.nextInt(20), // Random resting HR
      lastUpdate: DateTime.now(),
      isConnected: true,
      status: PlayerStatus.ready,
      isHost: true,
      colorCode: _getPlayerColor(0),
    );

    _currentSession = session;
    _currentPlayer = hostPlayer;
    _players[hostPlayerId] = hostPlayer;
    _sessionPlayers[sessionId]![hostPlayerId] = hostPlayer;

    _updateConnectionState(NetworkingConnectionState.connected);
    _sessionController.add(session);
    _playersController.add(connectedPlayers);

    // Send session created event
    final event = NetworkingEvent(
      type: NetworkingEventType.sessionUpdate,
      playerId: hostPlayerId,
      data: {'action': 'session_created', 'sessionId': sessionId},
      timestamp: DateTime.now(),
      sessionId: sessionId,
    );
    _addEvent(event);

    print('MockNetworkingService: Created session $sessionId with code $joinCode');
    return session;
  }

  @override
  Future<GameSession> joinSession({
    required String sessionCode,
    required String playerId,
    required String playerName,
  }) async {
    _updateConnectionState(NetworkingConnectionState.connecting);
    
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(700)));

    // Find session by join code
    GameSession? targetSession;
    for (final session in _globalSessions.values) {
      if (session.joinCode == sessionCode && session.canJoin) {
        targetSession = session;
        break;
      }
    }

    if (targetSession == null) {
      _updateConnectionState(NetworkingConnectionState.error);
      throw const NetworkingException(
        NetworkingError.sessionNotFound,
        'Session not found with provided code',
      );
    }

    if (targetSession.isFull) {
      _updateConnectionState(NetworkingConnectionState.error);
      throw const NetworkingException(
        NetworkingError.sessionFull,
        'Session is full',
      );
    }

    // Join the session
    final updatedPlayerIds = [...targetSession.playerIds, playerId];
    final updatedSession = targetSession.copyWith(playerIds: updatedPlayerIds);
    _globalSessions[updatedSession.id] = updatedSession;

    // Create player data
    final playerIndex = updatedPlayerIds.length - 1;
    final newPlayer = PlayerData(
      id: playerId,
      username: playerName,
      currentHeartRate: 65 + _random.nextInt(30), // Random HR
      lastUpdate: DateTime.now(),
      isConnected: true,
      status: PlayerStatus.ready,
      isHost: false,
      colorCode: _getPlayerColor(playerIndex),
    );

    _currentSession = updatedSession;
    _currentPlayer = newPlayer;
    _players[playerId] = newPlayer;
    _sessionPlayers[updatedSession.id]![playerId] = newPlayer;

    _updateConnectionState(NetworkingConnectionState.connected);
    _sessionController.add(updatedSession);
    _playersController.add(_sessionPlayers[updatedSession.id]!.values.toList());

    // Send player joined event
    final event = NetworkingEvent(
      type: NetworkingEventType.playerJoined,
      playerId: playerId,
      data: {
        'playerName': playerName,
        'playerId': playerId,
        'playerCount': updatedPlayerIds.length,
      },
      timestamp: DateTime.now(),
      sessionId: updatedSession.id,
    );
    _addEvent(event);

    print('MockNetworkingService: Player $playerName joined session ${updatedSession.id}');
    return updatedSession;
  }

  @override
  Future<GameSession> joinSessionById({
    required String sessionId,
    required String playerId,
    required String playerName,
  }) async {
    final session = _globalSessions[sessionId];
    if (session?.joinCode != null) {
      return joinSession(
        sessionCode: session!.joinCode!,
        playerId: playerId,
        playerName: playerName,
      );
    }
    throw const NetworkingException(
      NetworkingError.sessionNotFound,
      'Session not found',
    );
  }

  @override
  Future<void> leaveSession() async {
    if (_currentSession == null || _currentPlayer == null) return;

    final sessionId = _currentSession!.id;
    final playerId = _currentPlayer!.id;

    // Remove player from session
    final updatedPlayerIds = _currentSession!.playerIds
        .where((id) => id != playerId)
        .toList();

    if (updatedPlayerIds.isEmpty) {
      // Last player leaving - clean up session
      _globalSessions.remove(sessionId);
      _sessionPlayers.remove(sessionId);
      _sessionEvents.remove(sessionId);
    } else {
      // Update session
      final updatedSession = _currentSession!.copyWith(playerIds: updatedPlayerIds);
      _globalSessions[sessionId] = updatedSession;
      _sessionPlayers[sessionId]!.remove(playerId);
    }

    // Send player left event
    final event = NetworkingEvent(
      type: NetworkingEventType.playerLeft,
      playerId: playerId,
      data: {
        'playerName': _currentPlayer!.username,
        'playerId': playerId,
      },
      timestamp: DateTime.now(),
      sessionId: sessionId,
    );
    _addEvent(event);

    // Clear local state
    _currentSession = null;
    _currentPlayer = null;
    _players.clear();

    _updateConnectionState(NetworkingConnectionState.idle);
    _sessionController.add(null);
    _playersController.add([]);

    print('MockNetworkingService: Left session $sessionId');
  }

  @override
  Future<void> disconnect() async {
    if (_currentSession != null) {
      await leaveSession();
    }
    
    _updateConnectionState(NetworkingConnectionState.disconnected);
    await Future.delayed(const Duration(milliseconds: 100));
    _updateConnectionState(NetworkingConnectionState.idle);
  }

  @override
  Future<void> broadcastHeartRate({
    required int heartRate,
    DateTime? timestamp,
  }) async {
    if (_currentPlayer == null || _currentSession == null) return;

    // Update current player's heart rate
    final updatedPlayer = _currentPlayer!.copyWith(
      currentHeartRate: heartRate,
      lastUpdate: timestamp ?? DateTime.now(),
    );

    _currentPlayer = updatedPlayer;
    _players[updatedPlayer.id] = updatedPlayer;
    _sessionPlayers[_currentSession!.id]![updatedPlayer.id] = updatedPlayer;

    // Broadcast heart rate update event
    final event = NetworkingEvent(
      type: NetworkingEventType.heartRateUpdate,
      playerId: updatedPlayer.id,
      data: {
        'heartRate': heartRate,
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        'playerId': updatedPlayer.id,
      },
      timestamp: timestamp ?? DateTime.now(),
      sessionId: _currentSession!.id,
    );
    _addEvent(event);

    _playersController.add(_sessionPlayers[_currentSession!.id]!.values.toList());
  }

  @override
  Future<void> updatePlayerStatus({
    required PlayerStatus status,
    String? statusMessage,
  }) async {
    if (_currentPlayer == null || _currentSession == null) return;

    final updatedPlayer = _currentPlayer!.copyWith(status: status);
    _currentPlayer = updatedPlayer;
    _players[updatedPlayer.id] = updatedPlayer;
    _sessionPlayers[_currentSession!.id]![updatedPlayer.id] = updatedPlayer;

    final event = NetworkingEvent(
      type: NetworkingEventType.statusUpdate,
      playerId: updatedPlayer.id,
      data: {
        'status': status.name,
        'statusMessage': statusMessage,
        'playerId': updatedPlayer.id,
      },
      timestamp: DateTime.now(),
      sessionId: _currentSession!.id,
    );
    _addEvent(event);

    _playersController.add(_sessionPlayers[_currentSession!.id]!.values.toList());
  }

  @override
  Future<void> sendGameEvent({
    required NetworkingEventType eventType,
    required Map<String, dynamic> eventData,
  }) async {
    if (_currentSession == null) return;

    final event = NetworkingEvent(
      type: eventType,
      playerId: _currentPlayer?.id,
      data: eventData,
      timestamp: DateTime.now(),
      sessionId: _currentSession!.id,
    );
    _addEvent(event);
  }

  @override
  Future<void> updateSessionConfig({
    required GameConfig config,
    String? sessionName,
    int? maxPlayers,
  }) async {
    if (_currentSession == null || !_isCurrentPlayerHost()) {
      throw const NetworkingException(
        NetworkingError.permissionDenied,
        'Only session host can update configuration',
      );
    }

    final updatedSession = _currentSession!.copyWith(
      config: config,
      sessionName: sessionName,
      maxPlayers: maxPlayers,
    );

    _currentSession = updatedSession;
    _globalSessions[updatedSession.id] = updatedSession;

    final event = NetworkingEvent(
      type: NetworkingEventType.sessionUpdate,
      playerId: _currentPlayer?.id,
      data: {
        'action': 'config_updated',
        'sessionName': sessionName,
        'maxPlayers': maxPlayers,
      },
      timestamp: DateTime.now(),
      sessionId: updatedSession.id,
    );
    _addEvent(event);

    _sessionController.add(updatedSession);
  }

  @override
  Future<void> startGame() async {
    if (_currentSession == null || !_isCurrentPlayerHost()) {
      throw const NetworkingException(
        NetworkingError.permissionDenied,
        'Only session host can start the game',
      );
    }

    final updatedSession = _currentSession!.copyWith(
      state: GameState.countdown,
      gameStartTime: DateTime.now(),
    );

    _currentSession = updatedSession;
    _globalSessions[updatedSession.id] = updatedSession;

    final event = NetworkingEvent(
      type: NetworkingEventType.gameStateUpdate,
      playerId: _currentPlayer?.id,
      data: {
        'gameState': GameState.countdown.name,
        'action': 'start_game',
      },
      timestamp: DateTime.now(),
      sessionId: updatedSession.id,
    );
    _addEvent(event);

    _sessionController.add(updatedSession);

    // Simulate countdown and then start game
    _simulateGameStart();
  }

  @override
  Future<void> stopGame({bool pause = false}) async {
    if (_currentSession == null || !_isCurrentPlayerHost()) {
      throw const NetworkingException(
        NetworkingError.permissionDenied,
        'Only session host can stop the game',
      );
    }

    final newState = pause ? GameState.paused : GameState.completed;
    final updatedSession = _currentSession!.copyWith(state: newState);

    _currentSession = updatedSession;
    _globalSessions[updatedSession.id] = updatedSession;

    final event = NetworkingEvent(
      type: NetworkingEventType.gameStateUpdate,
      playerId: _currentPlayer?.id,
      data: {
        'gameState': newState.name,
        'action': pause ? 'pause_game' : 'stop_game',
      },
      timestamp: DateTime.now(),
      sessionId: updatedSession.id,
    );
    _addEvent(event);

    _sessionController.add(updatedSession);
  }

  @override
  Future<void> sendChatMessage(String message) async {
    if (_currentSession == null || _currentPlayer == null) return;

    final event = NetworkingEvent(
      type: NetworkingEventType.chatMessage,
      playerId: _currentPlayer!.id,
      data: {
        'message': message,
        'playerName': _currentPlayer!.username,
      },
      timestamp: DateTime.now(),
      sessionId: _currentSession!.id,
    );
    _addEvent(event);
  }

  @override
  Future<List<GameSession>> getPublicSessions({
    GameType? gameType,
    int limit = 20,
  }) async {
    await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));

    final publicSessions = _globalSessions.values
        .where((session) => 
            session.isPublic && 
            session.canJoin &&
            (gameType == null || session.gameType == gameType))
        .take(limit)
        .toList();

    return publicSessions;
  }

  @override
  Future<GameSession?> validateSessionCode(String sessionCode) async {
    await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));

    for (final session in _globalSessions.values) {
      if (session.joinCode == sessionCode) {
        return session;
      }
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> getSessionStats() async {
    if (_currentSession == null) return {};

    return {
      'sessionId': _currentSession!.id,
      'playerCount': _currentSession!.playerCount,
      'gameType': _currentSession!.gameType.name,
      'state': _currentSession!.state.name,
      'duration': DateTime.now().difference(_currentSession!.createdAt).inSeconds,
      'events': _sessionEvents[_currentSession!.id]?.length ?? 0,
    };
  }

  @override
  Future<int> ping() async {
    // Simulate realistic ping times
    final pingMs = 20 + _random.nextInt(80); // 20-100ms
    await Future.delayed(Duration(milliseconds: pingMs));
    return pingMs;
  }

  @override
  Stream<NetworkingEvent> listenToEvents(List<NetworkingEventType> eventTypes) {
    return eventsStream.where((event) => eventTypes.contains(event.type));
  }

  @override
  Stream<NetworkingEvent> listenToPlayer(String playerId) {
    return eventsStream.where((event) => event.playerId == playerId);
  }

  @override
  String generateSessionCode() {
    // Generate 6-character alphanumeric code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
    );
  }

  @override
  Future<void> dispose() async {
    if (_currentSession != null) {
      await leaveSession();
    }

    await _connectionStateController.close();
    await _eventsController.close();
    await _playersController.close();
    await _sessionController.close();
  }

  // Helper methods

  void _updateConnectionState(NetworkingConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _addEvent(NetworkingEvent event) {
    _eventHistory.add(event);
    _sessionEvents[event.sessionId]?.add(event);
    _eventsController.add(event);
  }

  bool _isCurrentPlayerHost() {
    return _currentPlayer != null && 
           _currentSession != null && 
           _currentPlayer!.id == _currentSession!.hostId;
  }

  int _getPlayerColor(int index) {
    const colors = [
      0xFF2196F3, // Blue
      0xFF4CAF50, // Green  
      0xFFFF9800, // Orange
      0xFF9C27B0, // Purple
      0xFFF44336, // Red
      0xFF00BCD4, // Cyan
      0xFFFF5722, // Deep Orange
      0xFF795548, // Brown
    ];
    return colors[index % colors.length];
  }

  Future<void> _simulateGameStart() async {
    // Wait for countdown (3 seconds)
    await Future.delayed(const Duration(seconds: 3));

    if (_currentSession?.state == GameState.countdown) {
      final updatedSession = _currentSession!.copyWith(
        state: GameState.active,
        gameStartTime: DateTime.now(),
      );

      _currentSession = updatedSession;
      _globalSessions[updatedSession.id] = updatedSession;

      final event = NetworkingEvent(
        type: NetworkingEventType.gameStateUpdate,
        playerId: _currentPlayer?.id,
        data: {
          'gameState': GameState.active.name,
          'action': 'game_started',
        },
        timestamp: DateTime.now(),
        sessionId: updatedSession.id,
      );
      _addEvent(event);

      _sessionController.add(updatedSession);
    }
  }
}