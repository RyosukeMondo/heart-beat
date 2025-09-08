import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'ble_types.dart';

/// Comprehensive logging system for BLE operations
/// 
/// Provides structured logging, error tracking, and debugging support
/// for all BLE components with Japanese localization support.
class BleLogger {
  static const String _loggerName = 'BLE';
  static final Map<String, List<BleLogEntry>> _logHistory = {};
  static const int _maxHistorySize = 500;
  static bool _debugMode = kDebugMode;
  
  /// Enable/disable debug mode
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }
  
  /// Log debug information
  static void debug(String component, String message, {Map<String, dynamic>? data}) {
    _log(BleLogLevel.debug, component, message, data: data);
  }
  
  /// Log informational message
  static void info(String component, String message, {Map<String, dynamic>? data}) {
    _log(BleLogLevel.info, component, message, data: data);
  }
  
  /// Log warning
  static void warning(String component, String message, {Map<String, dynamic>? data}) {
    _log(BleLogLevel.warning, component, message, data: data);
  }
  
  /// Log error with optional exception
  static void error(String component, String message, {Exception? exception, Map<String, dynamic>? data}) {
    _log(BleLogLevel.error, component, message, exception: exception, data: data);
  }
  
  /// Log critical error
  static void critical(String component, String message, {Exception? exception, Map<String, dynamic>? data}) {
    _log(BleLogLevel.critical, component, message, exception: exception, data: data);
  }
  
  /// Internal logging implementation
  static void _log(
    BleLogLevel level, 
    String component, 
    String message, {
    Exception? exception,
    Map<String, dynamic>? data,
  }) {
    final entry = BleLogEntry(
      timestamp: DateTime.now(),
      level: level,
      component: component,
      message: message,
      exception: exception,
      data: data,
    );
    
    // Add to history
    _logHistory.putIfAbsent(component, () => []).add(entry);
    
    // Maintain history size limit
    final history = _logHistory[component]!;
    if (history.length > _maxHistorySize) {
      history.removeAt(0);
    }
    
    // Output to console/debugger
    if (_debugMode || level.severity >= BleLogLevel.warning.severity) {
      _outputLog(entry);
    }
  }
  
  /// Output log entry to appropriate destination
  static void _outputLog(BleLogEntry entry) {
    final formattedMessage = entry.format();
    
    if (kDebugMode) {
      // Use developer.log for better Flutter debugging
      developer.log(
        formattedMessage,
        name: '$_loggerName.${entry.component}',
        level: entry.level.severity,
        error: entry.exception,
      );
    } else {
      // Fallback to print for release builds (if critical)
      if (entry.level == BleLogLevel.critical) {
        print('BLE CRITICAL: $formattedMessage');
      }
    }
  }
  
  /// Get log history for a component
  static List<BleLogEntry> getHistory(String component) {
    return List.from(_logHistory[component] ?? []);
  }
  
  /// Get all log history
  static Map<String, List<BleLogEntry>> getAllHistory() {
    return Map.from(_logHistory);
  }
  
  /// Clear log history
  static void clearHistory([String? component]) {
    if (component != null) {
      _logHistory.remove(component);
    } else {
      _logHistory.clear();
    }
  }
  
  /// Get error statistics
  static Map<String, int> getErrorStats() {
    final stats = <String, int>{};
    
    for (final entry in _logHistory.entries) {
      for (final logEntry in entry.value) {
        if (logEntry.level.severity >= BleLogLevel.error.severity) {
          final key = '${entry.key}.${logEntry.level.name}';
          stats[key] = (stats[key] ?? 0) + 1;
        }
      }
    }
    
    return stats;
  }
  
  /// Export logs for debugging
  static String exportLogs({String? component, BleLogLevel? minLevel}) {
    final buffer = StringBuffer();
    buffer.writeln('BLE Logs Export - ${DateTime.now().toIso8601String()}');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('Debug Mode: $_debugMode');
    buffer.writeln('=' * 60);
    
    final historyToExport = component != null 
        ? {component: _logHistory[component] ?? []}
        : _logHistory;
        
    for (final entry in historyToExport.entries) {
      buffer.writeln('\n[${entry.key}]');
      buffer.writeln('-' * 40);
      
      for (final logEntry in entry.value) {
        if (minLevel == null || logEntry.level.severity >= minLevel.severity) {
          buffer.writeln(logEntry.format());
        }
      }
    }
    
    return buffer.toString();
  }
}

/// Log severity levels
enum BleLogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warning(2, 'WARNING'),
  error(3, 'ERROR'),
  critical(4, 'CRITICAL');
  
  const BleLogLevel(this.severity, this.name);
  
  final int severity;
  final String name;
}

/// Individual log entry
class BleLogEntry {
  final DateTime timestamp;
  final BleLogLevel level;
  final String component;
  final String message;
  final Exception? exception;
  final Map<String, dynamic>? data;
  
  const BleLogEntry({
    required this.timestamp,
    required this.level,
    required this.component,
    required this.message,
    this.exception,
    this.data,
  });
  
  /// Format log entry for display
  String format() {
    final buffer = StringBuffer();
    
    // Timestamp and level
    buffer.write('${timestamp.toIso8601String()} [${level.name}] $component: ');
    
    // Main message
    buffer.write(message);
    
    // Additional data
    if (data != null && data!.isNotEmpty) {
      buffer.write(' | Data: ${data.toString()}');
    }
    
    // Exception details
    if (exception != null) {
      buffer.write(' | Exception: ${exception.toString()}');
    }
    
    return buffer.toString();
  }
  
  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'component': component,
      'message': message,
      'exception': exception?.toString(),
      'data': data,
    };
  }
}

/// Error reporting system for troubleshooting
class BleErrorReporter {
  static final List<BleErrorReport> _errorReports = [];
  static const int _maxReports = 50;
  
  /// Report a BLE error with context
  static void reportError({
    required String component,
    required BleError errorType,
    required String message,
    Exception? exception,
    Map<String, dynamic>? context,
    String? userAction,
  }) {
    final report = BleErrorReport(
      timestamp: DateTime.now(),
      component: component,
      errorType: errorType,
      message: message,
      exception: exception,
      context: context,
      userAction: userAction,
    );
    
    _errorReports.add(report);
    
    // Maintain size limit
    if (_errorReports.length > _maxReports) {
      _errorReports.removeAt(0);
    }
    
    // Log the error
    BleLogger.error(component, message, exception: exception, data: context);
  }
  
  /// Get all error reports
  static List<BleErrorReport> getReports() {
    return List.from(_errorReports);
  }
  
  /// Get reports filtered by component
  static List<BleErrorReport> getReportsForComponent(String component) {
    return _errorReports.where((r) => r.component == component).toList();
  }
  
  /// Clear error reports
  static void clearReports() {
    _errorReports.clear();
  }
  
  /// Generate troubleshooting report
  static String generateTroubleshootingReport() {
    final buffer = StringBuffer();
    buffer.writeln('BLE Troubleshooting Report');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Errors: ${_errorReports.length}');
    buffer.writeln('=' * 60);
    
    // Error type statistics
    final errorStats = <BleError, int>{};
    for (final report in _errorReports) {
      errorStats[report.errorType] = (errorStats[report.errorType] ?? 0) + 1;
    }
    
    buffer.writeln('\nError Type Statistics:');
    for (final entry in errorStats.entries) {
      buffer.writeln('  ${entry.key.name}: ${entry.value} occurrences');
    }
    
    // Recent errors
    buffer.writeln('\nRecent Errors (last 10):');
    final recentErrors = _errorReports.reversed.take(10).toList();
    for (final report in recentErrors) {
      buffer.writeln('  ${report.format()}');
    }
    
    // System information
    buffer.writeln('\nSystem Information:');
    buffer.writeln('  Platform: ${Platform.operatingSystem}');
    buffer.writeln('  Debug Mode: ${kDebugMode}');
    
    return buffer.toString();
  }
}

/// Individual error report
class BleErrorReport {
  final DateTime timestamp;
  final String component;
  final BleError errorType;
  final String message;
  final Exception? exception;
  final Map<String, dynamic>? context;
  final String? userAction;
  
  const BleErrorReport({
    required this.timestamp,
    required this.component,
    required this.errorType,
    required this.message,
    this.exception,
    this.context,
    this.userAction,
  });
  
  /// Format error report for display
  String format() {
    final buffer = StringBuffer();
    buffer.write('${timestamp.toIso8601String()} [$component] ${errorType.name}: $message');
    
    if (userAction != null) {
      buffer.write(' | User Action: $userAction');
    }
    
    return buffer.toString();
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'component': component,
      'errorType': errorType.name,
      'message': message,
      'exception': exception?.toString(),
      'context': context,
      'userAction': userAction,
    };
  }
}