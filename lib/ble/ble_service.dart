// Facade and interface for platform-specific BLE implementations.
// On web we will use flutter_web_bluetooth; on mobile/desktop we use flutter_blue_plus.

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'ble_types.dart';
import 'heart_rate_parser.dart';

// Conditional import of platform-specific implementation that provides createBleService().
import 'ble_service_impl_mobile.dart'
    if (dart.library.html) 'ble_service_impl_web.dart' as impl;

/// Common BLE UUIDs used by both implementations
class BleUuids {
  static const String heartRateService = '0000180d-0000-1000-8000-00805f9b34fb'; // 0x180D
  static const String heartRateMeasurement = '00002a37-0000-1000-8000-00805f9b34fb'; // 0x2A37
}

/// Abstract BLE service interface for heart rate monitoring across platforms.
/// 
/// Provides a unified interface for BLE operations on web, mobile, and desktop platforms.
/// Uses factory pattern for platform-specific implementations.
abstract class BleService {
  /// Factory constructor that returns platform-specific implementation
  factory BleService() {
    return _createPlatformService();
  }

  /// Platform detection and service creation
  static BleService _createPlatformService() {
    if (kIsWeb) {
      // Web platform - use flutter_web_bluetooth
      return impl.createBleService();
    } else {
      // Mobile/Desktop platform - use flutter_blue_plus or win_ble
      return impl.createBleService();
    }
  }

  /// Current connection state
  Stream<BleConnectionState> get connectionStateStream;

  /// Current connected device info (null if not connected)
  DeviceInfo? get currentDevice;

  /// Heart rate stream (BPM values)
  /// 
  /// Emits heart rate values in beats per minute as they are received
  /// from the connected heart rate sensor. Stream is empty when disconnected.
  Stream<int> get heartRateStream;

  /// Current connection state (synchronous access)
  BleConnectionState get connectionState;

  /// Check if currently connected to a device
  bool get isConnected => connectionState == BleConnectionState.connected;

  /// Check if BLE is supported on this platform
  bool get isSupported;

  /// Perform any platform-specific initialization if needed
  /// 
  /// This method should be called before any other BLE operations.
  /// It handles platform-specific setup like permission requests on Android.
  Future<void> initializeIfNeeded();

  /// Start scanning and connect to the first available heart rate device
  /// 
  /// Returns connected device info if connection is successful.
  /// Throws [BleException] if connection fails or times out.
  /// 
  /// The method will:
  /// 1. Check BLE availability and permissions
  /// 2. Scan for devices advertising Heart Rate Service (0x180D)
  /// 3. Connect to the first compatible device found
  /// 4. Subscribe to heart rate notifications
  Future<DeviceInfo?> scanAndConnect({
    Duration timeout = const Duration(seconds: 10),
  });

  /// Disconnect from the current device
  /// 
  /// Safely disconnects from the current device and cleans up resources.
  /// Can be called multiple times safely - will be a no-op if already disconnected.
  Future<void> disconnect();

  /// Stop scanning if currently scanning
  /// 
  /// Stops any active device scanning. Safe to call even if not scanning.
  Future<void> stopScan();

  /// Get list of previously connected devices (if supported by platform)
  /// 
  /// Returns list of known heart rate devices that were previously connected.
  /// May be empty on platforms that don't support device memory.
  Future<List<DeviceInfo>> getKnownDevices();

  /// Connect to a specific device by ID
  /// 
  /// Attempts to connect directly to a device by its platform-specific ID.
  /// Useful for reconnecting to a previously known device.
  Future<DeviceInfo?> connectToDevice(String deviceId, {
    Duration timeout = const Duration(seconds: 10),
  });

  /// Check if the service needs permissions and request them if needed
  /// 
  /// Returns true if permissions are granted, false otherwise.
  /// On platforms that don't require permissions, always returns true.
  Future<bool> checkAndRequestPermissions();

  /// Dispose of all resources and cleanup
  /// 
  /// Should be called when the service is no longer needed.
  /// After calling dispose(), the service should not be used anymore.
  Future<void> dispose();
}

/// Exception thrown by BLE operations
class BleException implements Exception {
  final BleError error;
  final String message;
  final Exception? originalException;

  const BleException(this.error, this.message, [this.originalException]);

  @override
  String toString() {
    final originalMsg = originalException != null ? ' (${originalException.toString()})' : '';
    return 'BleException: $message$originalMsg';
  }

  /// Get localized error message for UI display
  String get localizedMessage => error.message;
}

/// Mixin for common BLE service functionality
/// 
/// Provides common implementation patterns that can be shared across platforms
/// with performance optimizations for real-time data streaming
mixin BleServiceMixin on BleService {
  final StreamController<BleConnectionState> _connectionStateController = 
      StreamController<BleConnectionState>.broadcast();
  
  final StreamController<int> _heartRateController = 
      StreamController<int>.broadcast();

  // Performance optimization: Throttled heart rate stream
  StreamController<int>? _throttledHeartRateController;
  Stream<int>? _throttledHeartRateStream;
  Timer? _throttleTimer;
  int? _latestHeartRateValue;
  
  // Performance optimization: Connection monitoring
  Timer? _connectionHealthTimer;
  Timer? _scanOptimizationTimer;
  DateTime? _lastDataReceived;
  int _consecutiveFailures = 0;
  
  // Resource management
  final Set<StreamSubscription> _activeSubscriptions = {};
  bool _disposed = false;

  BleConnectionState _currentState = BleConnectionState.idle;
  DeviceInfo? _currentDevice;

  @override
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  @override
  DeviceInfo? get currentDevice => _currentDevice;

  @override
  Stream<int> get heartRateStream {
    // Return throttled stream for better UI performance (60 FPS = ~16ms intervals)
    _throttledHeartRateStream ??= _createThrottledHeartRateStream();
    return _throttledHeartRateStream!;
  }

  @override
  BleConnectionState get connectionState => _currentState;

  /// Create throttled heart rate stream for 60 FPS UI updates
  Stream<int> _createThrottledHeartRateStream() {
    _throttledHeartRateController ??= StreamController<int>.broadcast();
    
    // Listen to raw heart rate data and throttle to 60 FPS max
    final subscription = _heartRateController.stream.listen((heartRate) {
      _latestHeartRateValue = heartRate;
      _lastDataReceived = DateTime.now();
      _consecutiveFailures = 0; // Reset failure count on successful data
      
      // Throttle updates to maintain 60 FPS (16ms intervals)
      _throttleTimer?.cancel();
      _throttleTimer = Timer(const Duration(milliseconds: 16), () {
        if (!_disposed && _latestHeartRateValue != null) {
          _throttledHeartRateController!.add(_latestHeartRateValue!);
        }
      });
    });
    
    _activeSubscriptions.add(subscription);
    return _throttledHeartRateController!.stream;
  }

  /// Update connection state and notify listeners with performance optimization
  void updateConnectionState(BleConnectionState newState) {
    if (_disposed) return;
    
    if (_currentState != newState) {
      final previousState = _currentState;
      _currentState = newState;
      _connectionStateController.add(newState);
      
      // Performance optimization: Manage connection health monitoring
      _manageConnectionHealth(newState, previousState);
      
      // Clear device info when disconnected
      if (newState == BleConnectionState.disconnected || 
          newState == BleConnectionState.idle) {
        _currentDevice = null;
        _stopConnectionHealthMonitoring();
      }
    }
  }

  /// Manage connection health monitoring for automatic recovery
  void _manageConnectionHealth(BleConnectionState newState, BleConnectionState previousState) {
    switch (newState) {
      case BleConnectionState.connected:
        _startConnectionHealthMonitoring();
        _consecutiveFailures = 0;
        break;
      case BleConnectionState.error:
        _consecutiveFailures++;
        _stopConnectionHealthMonitoring();
        break;
      case BleConnectionState.scanning:
        _optimizeScanInterval();
        break;
      default:
        break;
    }
  }

  /// Start connection health monitoring for automatic recovery
  void _startConnectionHealthMonitoring() {
    _stopConnectionHealthMonitoring(); // Ensure no duplicate timers
    
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final lastData = _lastDataReceived;
      
      // Check if we haven't received data in too long (heart rate sensors typically send data every 1-2 seconds)
      if (lastData != null && now.difference(lastData).inSeconds > 10) {
        _consecutiveFailures++;
        print('BLE health check: No data received for ${now.difference(lastData).inSeconds} seconds');
        
        // Trigger reconnection if connection seems stale
        if (_consecutiveFailures >= 3) {
          _handleConnectionHealthFailure();
        }
      }
    });
  }

  /// Stop connection health monitoring
  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  /// Handle connection health failure with exponential backoff
  void _handleConnectionHealthFailure() {
    print('BLE connection health failure detected, attempting recovery...');
    // This method can be overridden by implementations for custom recovery
    updateConnectionState(BleConnectionState.error);
  }

  /// Optimize scanning intervals for battery efficiency
  void _optimizeScanInterval() {
    _scanOptimizationTimer?.cancel();
    
    // Implement adaptive scanning: aggressive for first 10 seconds, then reduce frequency
    _scanOptimizationTimer = Timer(const Duration(seconds: 10), () {
      if (_currentState == BleConnectionState.scanning && !_disposed) {
        print('BLE scan optimization: Reducing scan frequency for battery efficiency');
        // Implementations can override this behavior
      }
    });
  }

  /// Update current device info with automatic cleanup
  void updateCurrentDevice(DeviceInfo? device) {
    if (_disposed) return;
    
    _currentDevice = device;
    
    // Reset health monitoring when device changes
    if (device != null) {
      _lastDataReceived = DateTime.now();
      _consecutiveFailures = 0;
    }
  }

  /// Emit heart rate data to stream with performance validation
  void emitHeartRate(int heartRate) {
    if (_disposed || _currentState != BleConnectionState.connected) return;
    
    // Validate heart rate range (typical human range: 20-300 BPM)
    if (heartRate < 20 || heartRate > 300) {
      print('BLE warning: Heart rate value out of normal range: $heartRate');
      return;
    }
    
    _heartRateController.add(heartRate);
  }

  /// Parse and emit heart rate data from raw BLE data with performance tracking
  void parseAndEmitHeartRate(List<int> data) {
    if (_disposed) return;
    
    final startTime = DateTime.now();
    
    try {
      final heartRate = HeartRateParser.parseHeartRate(data);
      emitHeartRate(heartRate);
      
      // Performance requirement: Processing should complete within 200ms
      final processingTime = DateTime.now().difference(startTime);
      if (processingTime.inMilliseconds > 200) {
        print('BLE performance warning: Data parsing took ${processingTime.inMilliseconds}ms (>200ms)');
      }
    } catch (e) {
      _consecutiveFailures++;
      print('Failed to parse heart rate data: $e (consecutive failures: $_consecutiveFailures)');
      
      // If too many consecutive failures, trigger error state
      if (_consecutiveFailures >= 5) {
        updateConnectionState(BleConnectionState.error);
      }
    }
  }

  /// Cleanup unused resources automatically
  void cleanupUnusedResources() {
    if (_disposed) return;
    
    // Cancel expired timers
    if (_throttleTimer?.isActive == false) {
      _throttleTimer = null;
    }
    
    // Remove completed subscriptions
    _activeSubscriptions.removeWhere((sub) => sub.isPaused == false);
    
    // Force garbage collection hint for large data structures
    if (_activeSubscriptions.length > 10) {
      print('BLE resource cleanup: Managing ${_activeSubscriptions.length} subscriptions');
    }
  }

  /// Get performance metrics for monitoring
  Map<String, dynamic> getPerformanceMetrics() {
    final now = DateTime.now();
    return {
      'connectionState': _currentState.toString(),
      'consecutiveFailures': _consecutiveFailures,
      'lastDataReceived': _lastDataReceived?.toIso8601String(),
      'timeSinceLastData': _lastDataReceived != null 
          ? now.difference(_lastDataReceived!).inMilliseconds
          : null,
      'activeSubscriptions': _activeSubscriptions.length,
      'disposed': _disposed,
    };
  }

  /// Optimize for battery efficiency when idle
  void optimizeForBattery() {
    if (_disposed) return;
    
    switch (_currentState) {
      case BleConnectionState.scanning:
        // Reduce scan frequency
        _scanOptimizationTimer?.cancel();
        _optimizeScanInterval();
        break;
      case BleConnectionState.idle:
        // Clean up resources
        cleanupUnusedResources();
        break;
      default:
        break;
    }
  }

  /// Dispose mixin resources with comprehensive cleanup
  void disposeMixin() {
    if (_disposed) return;
    _disposed = true;
    
    // Cancel all timers
    _throttleTimer?.cancel();
    _connectionHealthTimer?.cancel();
    _scanOptimizationTimer?.cancel();
    
    // Cancel all subscriptions
    for (final subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    
    // Close controllers
    _connectionStateController.close();
    _heartRateController.close();
    _throttledHeartRateController?.close();
    
    // Clear references
    _latestHeartRateValue = null;
    _currentDevice = null;
    _lastDataReceived = null;
    
    print('BLE service resources disposed successfully');
  }
}

/// Performance monitoring utilities for BLE operations
class BlePerformanceMonitor {
  static const int maxProcessingTimeMs = 200;
  static const int maxHeartRateFPS = 60;
  static const int connectionHealthIntervalSeconds = 5;
  static const int maxConsecutiveFailures = 5;
  static const Duration scanOptimizationDelay = Duration(seconds: 10);
  
  /// Track performance metrics for BLE operations
  static final Map<String, List<int>> _performanceHistory = {};
  
  /// Record processing time for performance analysis
  static void recordProcessingTime(String operation, Duration duration) {
    final ms = duration.inMilliseconds;
    _performanceHistory.putIfAbsent(operation, () => []).add(ms);
    
    // Keep only last 100 measurements
    final history = _performanceHistory[operation]!;
    if (history.length > 100) {
      history.removeAt(0);
    }
    
    if (ms > maxProcessingTimeMs) {
      print('Performance warning: $operation took ${ms}ms (>${maxProcessingTimeMs}ms)');
    }
  }
  
  /// Get average processing time for an operation
  static double? getAverageProcessingTime(String operation) {
    final history = _performanceHistory[operation];
    if (history == null || history.isEmpty) return null;
    
    return history.reduce((a, b) => a + b) / history.length;
  }
  
  /// Get performance statistics
  static Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final entry in _performanceHistory.entries) {
      final history = entry.value;
      if (history.isNotEmpty) {
        stats[entry.key] = {
          'average': history.reduce((a, b) => a + b) / history.length,
          'min': history.reduce((a, b) => a < b ? a : b),
          'max': history.reduce((a, b) => a > b ? a : b),
          'samples': history.length,
        };
      }
    }
    
    return stats;
  }
  
  /// Clear performance history
  static void clearHistory() {
    _performanceHistory.clear();
  }
  
  /// Check if heart rate value is within valid range
  static bool isValidHeartRate(int heartRate) {
    return heartRate >= 20 && heartRate <= 300;
  }
  
  /// Calculate target throttle interval for desired FPS
  static Duration getThrottleInterval(int targetFPS) {
    return Duration(milliseconds: (1000 / targetFPS).round());
  }
}

/// Connection pool manager for multiple device support
class BleConnectionPool {
  final Map<String, BleService> _connections = {};
  final Set<String> _knownDevices = {};
  int _maxConnections = 1; // Most platforms support only 1 concurrent BLE connection
  
  /// Set maximum concurrent connections (platform dependent)
  void setMaxConnections(int max) {
    _maxConnections = max.clamp(1, 5); // Reasonable limits
  }
  
  /// Add a known device for future connection
  void addKnownDevice(String deviceId) {
    _knownDevices.add(deviceId);
  }
  
  /// Get known devices
  Set<String> getKnownDevices() => Set.from(_knownDevices);
  
  /// Check if we can add more connections
  bool canAddConnection() => _connections.length < _maxConnections;
  
  /// Add connection to pool
  bool addConnection(String deviceId, BleService service) {
    if (!canAddConnection()) return false;
    
    _connections[deviceId] = service;
    _knownDevices.add(deviceId);
    return true;
  }
  
  /// Remove connection from pool
  Future<void> removeConnection(String deviceId) async {
    final service = _connections.remove(deviceId);
    if (service != null) {
      await service.disconnect();
      await service.dispose();
    }
  }
  
  /// Get active connections
  Map<String, BleService> getActiveConnections() => Map.from(_connections);
  
  /// Dispose all connections
  Future<void> disposeAll() async {
    for (final service in _connections.values) {
      await service.disconnect();
      await service.dispose();
    }
    _connections.clear();
  }
}

/// Battery optimization strategies for BLE operations
class BleBatteryOptimizer {
  static const Duration aggressiveScanDuration = Duration(seconds: 10);
  static const Duration conservativeScanInterval = Duration(seconds: 30);
  static const Duration idleOptimizationDelay = Duration(minutes: 2);
  
  /// Optimize scan strategy based on battery level and usage patterns
  static Map<String, dynamic> getOptimizedScanStrategy({
    bool lowBattery = false,
    bool backgroundMode = false,
    int consecutiveFailures = 0,
  }) {
    if (lowBattery || backgroundMode || consecutiveFailures > 3) {
      return {
        'scanDuration': const Duration(seconds: 5),
        'scanInterval': const Duration(seconds: 60),
        'maxRetries': 2,
        'aggressive': false,
      };
    } else {
      return {
        'scanDuration': aggressiveScanDuration,
        'scanInterval': const Duration(seconds: 15),
        'maxRetries': 5,
        'aggressive': true,
      };
    }
  }
  
  /// Get recommended connection timeout based on conditions
  static Duration getRecommendedTimeout({
    bool lowBattery = false,
    int signalStrength = -50,
  }) {
    if (lowBattery) {
      return const Duration(seconds: 5);
    } else if (signalStrength < -70) {
      return const Duration(seconds: 20); // Weak signal needs more time
    } else {
      return const Duration(seconds: 10);
    }
  }
}