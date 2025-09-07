/// BLE connection states for heart rate monitoring
enum BleConnectionState {
  idle,
  scanning,
  connecting,
  connected,
  disconnected,
  error,
}

/// Standardized BLE error types
enum BleError {
  bluetoothNotSupported,
  bluetoothNotEnabled,
  permissionDenied,
  deviceNotFound,
  connectionFailed,
  connectionLost,
  serviceNotFound,
  characteristicNotFound,
  dataParsingError,
  unknownError,
}

/// Device information for BLE heart rate sensors
class DeviceInfo {
  final String id;
  final String platformName;
  final Map<String, dynamic>? manufacturerData;
  final int? rssi;

  const DeviceInfo({
    required this.id,
    required this.platformName,
    this.manufacturerData,
    this.rssi,
  });

  @override
  String toString() {
    return 'DeviceInfo(id: $id, platformName: $platformName, rssi: $rssi)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfo &&
        other.id == id &&
        other.platformName == platformName;
  }

  @override
  int get hashCode => Object.hash(id, platformName);

  /// Create a copy with updated properties
  DeviceInfo copyWith({
    String? id,
    String? platformName,
    Map<String, dynamic>? manufacturerData,
    int? rssi,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      platformName: platformName ?? this.platformName,
      manufacturerData: manufacturerData ?? this.manufacturerData,
      rssi: rssi ?? this.rssi,
    );
  }
}

/// Extension methods for BLE connection state
extension BleConnectionStateExtension on BleConnectionState {
  /// Check if the device is actively connected
  bool get isConnected => this == BleConnectionState.connected;
  
  /// Check if the device is in a working state
  bool get isWorking => 
      this == BleConnectionState.connected ||
      this == BleConnectionState.connecting ||
      this == BleConnectionState.scanning;

  /// Get user-friendly display text
  String get displayText {
    switch (this) {
      case BleConnectionState.idle:
        return 'アイドル';
      case BleConnectionState.scanning:
        return 'スキャン中';
      case BleConnectionState.connecting:
        return '接続中';
      case BleConnectionState.connected:
        return '接続済み';
      case BleConnectionState.disconnected:
        return '切断';
      case BleConnectionState.error:
        return 'エラー';
    }
  }
}

/// Extension methods for BLE error handling
extension BleErrorExtension on BleError {
  /// Get user-friendly error message in Japanese
  String get message {
    switch (this) {
      case BleError.bluetoothNotSupported:
        return 'Bluetoothがサポートされていません';
      case BleError.bluetoothNotEnabled:
        return 'Bluetoothが有効になっていません';
      case BleError.permissionDenied:
        return 'Bluetoothの権限が拒否されました';
      case BleError.deviceNotFound:
        return '心拍センサーが見つかりません';
      case BleError.connectionFailed:
        return '接続に失敗しました';
      case BleError.connectionLost:
        return '接続が切れました';
      case BleError.serviceNotFound:
        return '心拍サービスが見つかりません';
      case BleError.characteristicNotFound:
        return '心拍特性が見つかりません';
      case BleError.dataParsingError:
        return 'データの解析に失敗しました';
      case BleError.unknownError:
        return '不明なエラーが発生しました';
    }
  }
}