import 'dart:typed_data';
import 'ble_types.dart';
import 'ble_logger.dart';

/// Heart Rate Measurement parser following Bluetooth SIG specification
/// 
/// Handles parsing of Heart Rate Measurement characteristic (UUID: 0x2A37)
/// according to the Heart Rate Service specification (0x180D).
class HeartRateParser {
  /// Bluetooth SIG Heart Rate Service UUID
  static const String heartRateServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  
  /// Bluetooth SIG Heart Rate Measurement characteristic UUID
  static const String heartRateMeasurementUuid = '00002a37-0000-1000-8000-00805f9b34fb';

  /// Parse heart rate measurement data from BLE characteristic
  /// 
  /// Returns BPM as integer, or throws [BleError] if data is invalid.
  /// 
  /// The first byte contains flags:
  /// - Bit 0: Heart Rate Value Format (0 = UINT8, 1 = UINT16)
  /// - Bit 1: Sensor Contact Status (0 = not supported/not detected, 1 = supported/detected)
  /// - Bit 2: Sensor Contact Status (when bit 1 is 1: 0 = not detected, 1 = detected)
  /// - Bit 3: Energy Expended Status (0 = not present, 1 = present)
  /// - Bit 4-7: RR-Interval (0 = not present, 1 = present)
  static int parseHeartRate(List<int> data) {
    final context = {
      'dataLength': data.length,
      'rawData': data.take(8).toList(), // First 8 bytes for debugging
    };

    // Validate input data with comprehensive error reporting
    if (data.isEmpty) {
      BleErrorReporter.reportError(
        component: 'HeartRateParser',
        errorType: BleError.dataParsingError,
        message: 'Empty heart rate data received',
        context: context,
        userAction: 'Check sensor connection',
      );
      throw const BleDataParsingException(BleError.dataParsingError, 'Empty heart rate data');
    }
    
    if (data.length < 2) {
      BleErrorReporter.reportError(
        component: 'HeartRateParser',
        errorType: BleError.dataParsingError,
        message: 'Heart rate data too short: ${data.length} bytes',
        context: context,
        userAction: 'Verify sensor firmware compatibility',
      );
      throw BleDataParsingException(
        BleError.dataParsingError, 
        'Heart rate data too short: ${data.length} bytes (minimum 2 required)'
      );
    }

    try {
      BleLogger.debug('HeartRateParser', 'Parsing heart rate data', data: context);
      
      final bytes = Uint8List.fromList(data);
      final byteData = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

      // Parse flags from first byte
      final flags = byteData.getUint8(0);
      final isUint16Format = (flags & 0x01) == 0x01;
      
      BleLogger.debug('HeartRateParser', 'Parsed flags', data: {
        'flags': '0x${flags.toRadixString(16).padLeft(2, '0')}',
        'isUint16Format': isUint16Format,
        'sensorContactSupported': (flags & 0x02) == 0x02,
        'sensorContactDetected': (flags & 0x04) == 0x04,
        'energyExpendedPresent': (flags & 0x08) == 0x08,
        'rrIntervalPresent': (flags & 0x10) == 0x10,
      });
      
      // Parse heart rate value based on format flag
      int heartRate;
      if (isUint16Format) {
        // 16-bit format: requires at least 3 bytes (flags + 2 bytes for heart rate)
        if (bytes.lengthInBytes < 3) {
          BleErrorReporter.reportError(
            component: 'HeartRateParser',
            errorType: BleError.dataParsingError,
            message: 'Insufficient data for 16-bit format: ${bytes.lengthInBytes} bytes',
            context: context..addAll({'requiredBytes': 3}),
            userAction: 'Check sensor data transmission',
          );
          throw BleDataParsingException(
            BleError.dataParsingError, 
            'Insufficient data for 16-bit heart rate format: ${bytes.lengthInBytes} bytes (minimum 3 required)'
          );
        }
        // Read 16-bit value in little-endian format as per Bluetooth specification
        heartRate = byteData.getUint16(1, Endian.little);
        BleLogger.debug('HeartRateParser', 'Parsed 16-bit heart rate', data: {'heartRate': heartRate});
      } else {
        // 8-bit format: requires at least 2 bytes (flags + 1 byte for heart rate)
        if (bytes.lengthInBytes < 2) {
          BleErrorReporter.reportError(
            component: 'HeartRateParser',
            errorType: BleError.dataParsingError,
            message: 'Insufficient data for 8-bit format: ${bytes.lengthInBytes} bytes',
            context: context..addAll({'requiredBytes': 2}),
            userAction: 'Check sensor data transmission',
          );
          throw BleDataParsingException(
            BleError.dataParsingError, 
            'Insufficient data for 8-bit heart rate format: ${bytes.lengthInBytes} bytes (minimum 2 required)'
          );
        }
        heartRate = byteData.getUint8(1);
        BleLogger.debug('HeartRateParser', 'Parsed 8-bit heart rate', data: {'heartRate': heartRate});
      }

      // Validate heart rate range with detailed reporting
      if (heartRate < 20) {
        BleErrorReporter.reportError(
          component: 'HeartRateParser',
          errorType: BleError.dataParsingError,
          message: 'Heart rate below minimum threshold: $heartRate BPM',
          context: context..addAll({'heartRate': heartRate, 'threshold': 20}),
          userAction: 'Check sensor placement and contact',
        );
        throw BleDataParsingException(
          BleError.dataParsingError, 
          'Heart rate below physiological minimum (20 BPM): $heartRate'
        );
      }
      
      if (heartRate > 300) {
        BleErrorReporter.reportError(
          component: 'HeartRateParser',
          errorType: BleError.dataParsingError,
          message: 'Heart rate above maximum threshold: $heartRate BPM',
          context: context..addAll({'heartRate': heartRate, 'threshold': 300}),
          userAction: 'Check for sensor interference or malfunction',
        );
        throw BleDataParsingException(
          BleError.dataParsingError, 
          'Heart rate above physiological maximum (300 BPM): $heartRate'
        );
      }

      // Log successful parsing
      BleLogger.debug('HeartRateParser', 'Successfully parsed heart rate', data: {
        'heartRate': heartRate,
        'format': isUint16Format ? '16-bit' : '8-bit',
        'dataLength': data.length,
      });

      return heartRate;

    } catch (e) {
      if (e is BleDataParsingException) {
        rethrow;
      }
      
      // Handle unexpected exceptions
      final errorMessage = 'Unexpected error parsing heart rate data: ${e.toString()}';
      BleLogger.error('HeartRateParser', errorMessage, exception: e as Exception?, data: context);
      
      BleErrorReporter.reportError(
        component: 'HeartRateParser',
        errorType: BleError.dataParsingError,
        message: errorMessage,
        exception: e as Exception?,
        context: context,
        userAction: 'Restart sensor and retry connection',
      );
      
      // Wrap any other exceptions as BLE parsing errors
      throw BleDataParsingException(
        BleError.dataParsingError, 
        'Failed to parse heart rate data: ${e.toString()}'
      );
    }
  }

  /// Try to parse heart rate data, returning null on any error
  /// 
  /// This is a safe wrapper around [parseHeartRate] that catches
  /// all exceptions and returns null instead. Use for scenarios where
  /// you want to gracefully handle parsing failures.
  static int? tryParseHeartRate(List<int> data) {
    try {
      return parseHeartRate(data);
    } catch (e) {
      BleLogger.warning('HeartRateParser', 'Safe parsing failed, returning null', data: {
        'dataLength': data.length,
        'error': e.toString(),
      });
      return null;
    }
  } catch (e) {
      return null;
    }
  }

  /// Validate heart rate measurement data format
  /// 
  /// Returns true if the data appears to be valid heart rate measurement data
  static bool isValidHeartRateData(List<int> data) {
    try {
      parseHeartRate(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Extract sensor contact status from heart rate measurement
  /// 
  /// Returns:
  /// - null: Sensor contact feature not supported
  /// - false: Sensor contact feature supported but contact not detected
  /// - true: Sensor contact feature supported and contact detected
  static bool? getSensorContactStatus(List<int> data) {
    if (data.isEmpty) return null;
    
    final flags = data[0];
    final contactSupported = (flags & 0x02) == 0x02;
    
    if (!contactSupported) {
      return null; // Feature not supported
    }
    
    final contactDetected = (flags & 0x04) == 0x04;
    return contactDetected;
  }

  /// Check if energy expended field is present in the data
  static bool hasEnergyExpended(List<int> data) {
    if (data.isEmpty) return false;
    final flags = data[0];
    return (flags & 0x08) == 0x08;
  }

  /// Check if RR-Interval data is present
  static bool hasRRInterval(List<int> data) {
    if (data.isEmpty) return false;
    final flags = data[0];
    return (flags & 0x10) == 0x10;
  }
}

/// Exception thrown when heart rate data parsing fails
class BleDataParsingException implements Exception {
  final BleError error;
  final String message;

  const BleDataParsingException(this.error, this.message);

  @override
  String toString() => 'BleDataParsingException: $message (${error.name})';
}