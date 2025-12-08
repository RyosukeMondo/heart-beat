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

/// Extension methods for BLE error handling with comprehensive error management
extension BleErrorExtension on BleError {
  /// Get user-friendly error message in Japanese
  String get message {
    switch (this) {
      case BleError.bluetoothNotSupported:
        return 'このデバイスではBluetoothがサポートされていません。対応デバイスをご利用ください。';
      case BleError.bluetoothNotEnabled:
        return 'Bluetoothが有効になっていません。設定からBluetoothを有効にしてください。';
      case BleError.permissionDenied:
        return 'Bluetoothの使用権限が拒否されました。設定から権限を許可してください。';
      case BleError.deviceNotFound:
        return '心拍センサーが見つかりません。センサーの電源を確認し、近づけてから再試行してください。';
      case BleError.connectionFailed:
        return '心拍センサーとの接続に失敗しました。センサーが他のデバイスに接続されていないか確認してください。';
      case BleError.connectionLost:
        return 'センサーとの接続が切れました。センサーの電池残量を確認し、近づけて再接続してください。';
      case BleError.serviceNotFound:
        return '心拍サービスが見つかりません。対応する心拍センサーであることを確認してください。';
      case BleError.characteristicNotFound:
        return '心拍データの受信機能が見つかりません。センサーのファームウェアを確認してください。';
      case BleError.dataParsingError:
        return '心拍データの解析に失敗しました。センサーが正常に動作しているか確認してください。';
      case BleError.unknownError:
        return '不明なエラーが発生しました。アプリを再起動してから再試行してください。';
    }
  }
  
  /// Get detailed technical error message for debugging
  String get technicalMessage {
    switch (this) {
      case BleError.bluetoothNotSupported:
        return 'Bluetooth Low Energy not supported on this platform';
      case BleError.bluetoothNotEnabled:
        return 'Bluetooth adapter is disabled or unavailable';
      case BleError.permissionDenied:
        return 'Required Bluetooth permissions not granted';
      case BleError.deviceNotFound:
        return 'No Heart Rate Service devices found during scan';
      case BleError.connectionFailed:
        return 'Failed to establish BLE connection to device';
      case BleError.connectionLost:
        return 'BLE connection terminated unexpectedly';
      case BleError.serviceNotFound:
        return 'Heart Rate Service (0x180D) not available on device';
      case BleError.characteristicNotFound:
        return 'Heart Rate Measurement characteristic (0x2A37) not found';
      case BleError.dataParsingError:
        return 'Invalid or corrupted heart rate measurement data';
      case BleError.unknownError:
        return 'Unhandled exception in BLE subsystem';
    }
  }
  
  /// Get error severity level
  BleSeverity get severity {
    switch (this) {
      case BleError.bluetoothNotSupported:
      case BleError.bluetoothNotEnabled:
        return BleSeverity.critical;
      case BleError.permissionDenied:
      case BleError.serviceNotFound:
      case BleError.characteristicNotFound:
        return BleSeverity.high;
      case BleError.deviceNotFound:
      case BleError.connectionFailed:
        return BleSeverity.medium;
      case BleError.connectionLost:
      case BleError.dataParsingError:
        return BleSeverity.low;
      case BleError.unknownError:
        return BleSeverity.high;
    }
  }
  
  /// Get suggested user action
  String get suggestedAction {
    switch (this) {
      case BleError.bluetoothNotSupported:
        return '対応デバイスの使用をご検討ください';
      case BleError.bluetoothNotEnabled:
        return '設定 > Bluetooth から有効にしてください';
      case BleError.permissionDenied:
        return '設定 > アプリ > 権限 から許可してください';
      case BleError.deviceNotFound:
        return 'センサーの電源確認、近づける、再スキャン';
      case BleError.connectionFailed:
        return '他デバイスとの接続を確認、センサー再起動';
      case BleError.connectionLost:
        return 'センサーに近づく、電池残量確認';
      case BleError.serviceNotFound:
        return '対応センサーであることを確認';
      case BleError.characteristicNotFound:
        return 'センサーファームウェア更新確認';
      case BleError.dataParsingError:
        return 'センサー再起動、接続再試行';
      case BleError.unknownError:
        return 'アプリ再起動、問題が続く場合は報告';
    }
  }
  
  /// Check if error is recoverable
  bool get isRecoverable {
    switch (this) {
      case BleError.bluetoothNotSupported:
        return false;
      case BleError.bluetoothNotEnabled:
      case BleError.permissionDenied:
      case BleError.deviceNotFound:
      case BleError.connectionFailed:
      case BleError.connectionLost:
      case BleError.dataParsingError:
        return true;
      case BleError.serviceNotFound:
      case BleError.characteristicNotFound:
      case BleError.unknownError:
        return false; // Usually indicates incompatible device
    }
  }
}

/// Error severity levels
enum BleSeverity {
  low(1, 'Low'),
  medium(2, 'Medium'), 
  high(3, 'High'),
  critical(4, 'Critical');
  
  const BleSeverity(this.level, this.name);
  
  final int level;
  final String name;
}