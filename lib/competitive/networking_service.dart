/// Abstract networking service interface for real-time multiplayer heart rate competitions
/// 
/// Provides a unified interface for networking operations across platforms.
/// Uses factory pattern for platform-specific implementations with different backends
/// (WebSocket, WebRTC, Firebase Realtime Database, Socket.IO, etc.).

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'models/models.dart';

// Conditional import of platform-specific implementation that provides createNetworkingService().
import 'networking_service_impl_mobile.dart'
    if (dart.library.html) 'networking_service_impl_web.dart' as impl;

/// Connection states for multiplayer networking
enum NetworkingConnectionState {
  /// Not connected to any session
  idle,
  /// Attempting to connect to a session
  connecting,
  /// Successfully connected to a session
  connected,
  /// Connection lost or disconnected
  disconnected,
  /// Error occurred during connection
  error,
}

/// Types of network events for real-time communication
enum NetworkingEventType {
  /// Player joined the session
  playerJoined,
  /// Player left the session
  playerLeft,
  /// Player heart rate data update
  heartRateUpdate,
  /// Player status change (ready, playing, etc.)
  statusUpdate,
  /// Game state change (lobby, active, completed, etc.)
  gameStateUpdate,
  /// Game-specific event (stimulus, scoring, etc.)
  gameEvent,
  /// Session configuration change
  sessionUpdate,
  /// Chat message from player
  chatMessage,
  /// System notification
  systemNotification,
}

/// Network event data structure
class NetworkingEvent {
  /// Type of the event
  final NetworkingEventType type;
  
  /// ID of the player who triggered the event (null for system events)
  final String? playerId;
  
  /// Event payload data
  final Map<String, dynamic> data;
  
  /// Timestamp when the event occurred
  final DateTime timestamp;
  
  /// Session ID where the event occurred
  final String sessionId;

  const NetworkingEvent({
    required this.type,
    required this.data,
    required this.timestamp,
    required this.sessionId,
    this.playerId,
  });

  /// Create NetworkingEvent from JSON map
  factory NetworkingEvent.fromJson(Map<String, dynamic> json) {
    return NetworkingEvent(
      type: NetworkingEventType.values.byName(json['type'] as String),
      playerId: json['playerId'] as String?,
      data: Map<String, dynamic>.from(json['data'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
      sessionId: json['sessionId'] as String,
    );
  }

  /// Convert NetworkingEvent to JSON map
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'playerId': playerId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
    };
  }

  @override
  String toString() {
    return 'NetworkingEvent(type: $type, playerId: $playerId, session: $sessionId)';
  }
}

/// Networking error types
enum NetworkingError {
  connectionFailed,
  sessionNotFound,
  sessionFull,
  invalidSessionCode,
  permissionDenied,
  networkTimeout,
  serverError,
  unknownError,
}

/// Custom exception for networking operations
class NetworkingException implements Exception {
  final NetworkingError error;
  final String message;
  final String? details;

  const NetworkingException(this.error, this.message, [this.details]);

  @override
  String toString() {
    return 'NetworkingException: $message${details != null ? ' ($details)' : ''}';
  }

  /// Get user-friendly error message
  String get userMessage {
    switch (error) {
      case NetworkingError.connectionFailed:
        return 'Failed to connect to game session. Please check your internet connection.';
      case NetworkingError.sessionNotFound:
        return 'Game session not found. Please check the session code.';
      case NetworkingError.sessionFull:
        return 'Game session is full. Try joining a different session.';
      case NetworkingError.invalidSessionCode:
        return 'Invalid session code. Please check the code and try again.';
      case NetworkingError.permissionDenied:
        return 'You don\'t have permission to perform this action.';
      case NetworkingError.networkTimeout:
        return 'Connection timed out. Please check your internet connection.';
      case NetworkingError.serverError:
        return 'Server error occurred. Please try again later.';
      case NetworkingError.unknownError:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

/// Abstract networking service interface for real-time multiplayer heart rate gaming
/// 
/// Provides methods for session management, real-time communication, and event streaming
/// for competitive heart rate gaming sessions.
abstract class NetworkingService {
  /// Factory constructor that returns platform-specific implementation
  factory NetworkingService() {
    return _createPlatformService();
  }

  /// Platform detection and service creation
  static NetworkingService _createPlatformService() {
    if (kIsWeb) {
      // Web platform - use WebSocket or WebRTC
      return impl.createNetworkingService();
    } else {
      // Mobile/Desktop platform - use Socket.IO, WebSocket, or native networking
      return impl.createNetworkingService();
    }
  }

  /// Current connection state stream
  Stream<NetworkingConnectionState> get connectionStateStream;

  /// Stream of all networking events
  Stream<NetworkingEvent> get eventsStream;

  /// Stream of connected players data
  Stream<List<PlayerData>> get playersStream;

  /// Stream of current session data
  Stream<GameSession?> get sessionStream;

  /// Current connection state (synchronous access)
  NetworkingConnectionState get connectionState;

  /// Current session information (null if not in a session)
  GameSession? get currentSession;

  /// List of currently connected players
  List<PlayerData> get connectedPlayers;

  /// Current player's data
  PlayerData? get currentPlayer;

  /// Check if currently connected to a session
  bool get isConnected => connectionState == NetworkingConnectionState.connected;

  /// Check if networking is supported on this platform
  bool get isSupported;

  /// Perform any platform-specific initialization if needed
  /// 
  /// This method should be called before any other networking operations.
  /// It handles platform-specific setup like WebSocket initialization.
  Future<void> initialize();

  // Session Management Methods

  /// Create a new multiplayer session
  /// 
  /// Creates a new game session with the specified configuration and returns
  /// the session information including join code for other players.
  /// 
  /// Throws [NetworkingException] if session creation fails.
  Future<GameSession> createSession({
    required GameType gameType,
    required GameConfig config,
    required String hostPlayerId,
    required String hostPlayerName,
    int maxPlayers = 8,
    bool isPublic = false,
    String? sessionName,
  });

  /// Join an existing session using session code
  /// 
  /// Attempts to join an existing session using the provided session code.
  /// Returns the session information if successful.
  /// 
  /// Throws [NetworkingException] if joining fails (session not found, full, etc.).
  Future<GameSession> joinSession({
    required String sessionCode,
    required String playerId,
    required String playerName,
  });

  /// Join an existing session directly by session ID
  /// 
  /// Similar to joinSession but uses direct session ID instead of join code.
  /// Useful for reconnecting to known sessions.
  Future<GameSession> joinSessionById({
    required String sessionId,
    required String playerId,
    required String playerName,
  });

  /// Leave the current session
  /// 
  /// Gracefully leaves the current session and notifies other players.
  /// Safe to call even if not in a session.
  Future<void> leaveSession();

  /// Disconnect from networking service
  /// 
  /// Disconnects from the networking service and cleans up resources.
  /// Automatically leaves any current session.
  Future<void> disconnect();

  // Real-time Communication Methods

  /// Broadcast heart rate data to other players
  /// 
  /// Sends the current player's heart rate data to all other players
  /// in the session. Should be called regularly during active games.
  Future<void> broadcastHeartRate({
    required int heartRate,
    DateTime? timestamp,
  });

  /// Update player status
  /// 
  /// Notifies other players of status changes (ready, playing, eliminated, etc.).
  Future<void> updatePlayerStatus({
    required PlayerStatus status,
    String? statusMessage,
  });

  /// Send game event
  /// 
  /// Sends game-specific events (scoring, elimination, achievements, etc.)
  /// to other players in the session.
  Future<void> sendGameEvent({
    required NetworkingEventType eventType,
    required Map<String, dynamic> eventData,
  });

  /// Update session configuration
  /// 
  /// Updates session settings. Only available to session host.
  /// Throws [NetworkingException] if not authorized.
  Future<void> updateSessionConfig({
    required GameConfig config,
    String? sessionName,
    int? maxPlayers,
  });

  /// Start game in the session
  /// 
  /// Initiates the game for all players in the session.
  /// Only available to session host.
  Future<void> startGame();

  /// Stop/pause game in the session
  /// 
  /// Stops or pauses the current game for all players.
  /// Only available to session host.
  Future<void> stopGame({bool pause = false});

  /// Send chat message to session
  /// 
  /// Sends a text message to all players in the session.
  Future<void> sendChatMessage(String message);

  // Query Methods

  /// Get list of public sessions
  /// 
  /// Returns a list of public sessions that can be joined.
  /// Useful for session browsing and discovery.
  Future<List<GameSession>> getPublicSessions({
    GameType? gameType,
    int limit = 20,
  });

  /// Check if session code is valid
  /// 
  /// Validates a session code without actually joining the session.
  /// Returns session information if valid, null if invalid.
  Future<GameSession?> validateSessionCode(String sessionCode);

  /// Get session statistics
  /// 
  /// Returns current session statistics and metrics.
  Future<Map<String, dynamic>> getSessionStats();

  /// Ping the server to check connection quality
  /// 
  /// Returns round-trip time in milliseconds.
  /// Useful for displaying connection quality to users.
  Future<int> ping();

  // Event Filtering Methods

  /// Listen to specific event types
  /// 
  /// Returns a filtered stream containing only the specified event types.
  Stream<NetworkingEvent> listenToEvents(List<NetworkingEventType> eventTypes);

  /// Listen to events from specific players
  /// 
  /// Returns a filtered stream containing only events from the specified players.
  Stream<NetworkingEvent> listenToPlayer(String playerId);

  /// Listen to game events only
  /// 
  /// Convenience method to listen to game-related events only.
  Stream<NetworkingEvent> get gameEventsStream => listenToEvents([
    NetworkingEventType.gameStateUpdate,
    NetworkingEventType.gameEvent,
  ]);

  /// Listen to heart rate updates only
  /// 
  /// Convenience method to listen to heart rate data from all players.
  Stream<NetworkingEvent> get heartRateEventsStream => listenToEvents([
    NetworkingEventType.heartRateUpdate,
  ]);

  // Utility Methods

  /// Generate a unique session code
  /// 
  /// Generates a short, user-friendly session code for sharing.
  /// Typically 6-8 characters long and easy to communicate verbally.
  String generateSessionCode();

  /// Clean up resources
  /// 
  /// Performs cleanup operations. Should be called when the service
  /// is no longer needed (e.g., app termination).
  Future<void> dispose();
}

/// Extension methods for NetworkingConnectionState
extension NetworkingConnectionStateExtension on NetworkingConnectionState {
  /// Check if connection is working
  bool get isWorking => this == NetworkingConnectionState.connected ||
                       this == NetworkingConnectionState.connecting;

  /// Check if connection allows operations
  bool get allowsOperations => this == NetworkingConnectionState.connected;

  /// Get user-friendly display text
  String get displayText {
    switch (this) {
      case NetworkingConnectionState.idle:
        return 'Not Connected';
      case NetworkingConnectionState.connecting:
        return 'Connecting...';
      case NetworkingConnectionState.connected:
        return 'Connected';
      case NetworkingConnectionState.disconnected:
        return 'Disconnected';
      case NetworkingConnectionState.error:
        return 'Connection Error';
    }
  }

  /// Get status color for UI display
  int get colorCode {
    switch (this) {
      case NetworkingConnectionState.idle:
        return 0xFF9E9E9E; // Grey
      case NetworkingConnectionState.connecting:
        return 0xFFFF9800; // Orange
      case NetworkingConnectionState.connected:
        return 0xFF4CAF50; // Green
      case NetworkingConnectionState.disconnected:
        return 0xFF607D8B; // Blue Grey
      case NetworkingConnectionState.error:
        return 0xFFF44336; // Red
    }
  }
}

/// Extension methods for NetworkingEventType
extension NetworkingEventTypeExtension on NetworkingEventType {
  /// Check if event is player-related
  bool get isPlayerEvent => [
    NetworkingEventType.playerJoined,
    NetworkingEventType.playerLeft,
    NetworkingEventType.heartRateUpdate,
    NetworkingEventType.statusUpdate,
  ].contains(this);

  /// Check if event is game-related
  bool get isGameEvent => [
    NetworkingEventType.gameStateUpdate,
    NetworkingEventType.gameEvent,
  ].contains(this);

  /// Check if event is system-related
  bool get isSystemEvent => [
    NetworkingEventType.sessionUpdate,
    NetworkingEventType.systemNotification,
  ].contains(this);

  /// Get display text for UI
  String get displayText {
    switch (this) {
      case NetworkingEventType.playerJoined:
        return 'Player Joined';
      case NetworkingEventType.playerLeft:
        return 'Player Left';
      case NetworkingEventType.heartRateUpdate:
        return 'Heart Rate Update';
      case NetworkingEventType.statusUpdate:
        return 'Status Update';
      case NetworkingEventType.gameStateUpdate:
        return 'Game State Change';
      case NetworkingEventType.gameEvent:
        return 'Game Event';
      case NetworkingEventType.sessionUpdate:
        return 'Session Update';
      case NetworkingEventType.chatMessage:
        return 'Chat Message';
      case NetworkingEventType.systemNotification:
        return 'System Notification';
    }
  }

  /// Get icon code for UI display
  int get iconCode {
    switch (this) {
      case NetworkingEventType.playerJoined:
        return 0xe7fd; // Icons.person_add
      case NetworkingEventType.playerLeft:
        return 0xe7fe; // Icons.person_remove
      case NetworkingEventType.heartRateUpdate:
        return 0xe87d; // Icons.favorite
      case NetworkingEventType.statusUpdate:
        return 0xe88f; // Icons.info
      case NetworkingEventType.gameStateUpdate:
        return 0xe40a; // Icons.sports_esports
      case NetworkingEventType.gameEvent:
        return 0xe1e1; // Icons.event
      case NetworkingEventType.sessionUpdate:
        return 0xe8b8; // Icons.settings
      case NetworkingEventType.chatMessage:
        return 0xe0b7; // Icons.message
      case NetworkingEventType.systemNotification:
        return 0xe7f4; // Icons.notifications
    }
  }
}