import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/ble/heart_rate_parser.dart';
import 'package:heart_beat/ble/ble_types.dart';

void main() {
  group('HeartRateParser Tests', () {
    test('parses 8-bit heart rate data correctly', () {
      // Test 8-bit format: flags=0x00, hr=72 bpm
      final data = [0x00, 72];
      final result = HeartRateParser.parseHeartRate(data);
      
      expect(result, 72);
    });

    test('parses 16-bit heart rate data correctly', () {
      // Test 16-bit format: flags=0x01, hr=300 bpm (0x012C little-endian)
      final data = [0x01, 0x2C, 0x01]; // 0x012C = 300 in little-endian
      final result = HeartRateParser.parseHeartRate(data);
      
      expect(result, 300);
    });

    test('handles minimum valid heart rate', () {
      // Test minimum heart rate (30 bpm as per physiological limits)
      final data = [0x00, 30];
      final result = HeartRateParser.parseHeartRate(data);
      
      expect(result, 30);
    });

    test('handles maximum valid heart rate within range', () {
      // Test maximum valid heart rate (220 bpm as per physiological limits)
      final data = [0x00, 220];
      final result = HeartRateParser.parseHeartRate(data);
      
      expect(result, 220);
    });

    test('handles 16-bit heart rate within valid range', () {
      // Test 16-bit heart rate within valid range (200 bpm)
      final data = [0x01, 0xC8, 0x00]; // 0x00C8 = 200 in little-endian
      final result = HeartRateParser.parseHeartRate(data);
      
      expect(result, 200);
    });

    test('throws BleDataParsingException for empty data', () {
      expect(
        () => HeartRateParser.parseHeartRate([]),
        throwsA(isA<BleDataParsingException>()),
      );
    });

    test('throws BleDataParsingException for single byte data', () {
      // Single byte is not enough - need at least flags + heart rate
      expect(
        () => HeartRateParser.parseHeartRate([0x00]),
        throwsA(isA<BleDataParsingException>()),
      );
    });

    test('throws BleDataParsingException for 16-bit format with insufficient data', () {
      // 16-bit format requires at least 3 bytes: flags + 2 bytes for HR
      expect(
        () => HeartRateParser.parseHeartRate([0x01, 0x2C]), // Missing second HR byte
        throwsA(isA<BleDataParsingException>()),
      );
    });

    test('throws BleDataParsingException for heart rate out of range', () {
      // Test heart rate too low (< 30 bpm)
      expect(
        () => HeartRateParser.parseHeartRate([0x00, 25]),
        throwsA(isA<BleDataParsingException>()),
      );

      // Test heart rate too high (> 220 bpm)
      expect(
        () => HeartRateParser.parseHeartRate([0x00, 250]),
        throwsA(isA<BleDataParsingException>()),
      );
    });

    test('handles additional data in packet correctly', () {
      // Real BLE packets often contain additional sensor data
      // Test that parser correctly extracts HR from longer packets
      
      // 8-bit format with additional data
      final data8bit = [0x00, 85, 0x12, 0x34, 0x56]; // HR=85, extra data
      final result8bit = HeartRateParser.parseHeartRate(data8bit);
      expect(result8bit, 85);
      
      // 16-bit format with additional data (within valid range)
      final data16bit = [0x01, 0x78, 0x00, 0xAB, 0xCD]; // HR=120, extra data
      final result16bit = HeartRateParser.parseHeartRate(data16bit);
      expect(result16bit, 120);
    });

    test('handles realistic heart rate values', () {
      // Test common heart rate ranges
      final testCases = [
        ([0x00, 60], 60),   // Resting HR
        ([0x00, 80], 80),   // Normal HR
        ([0x00, 120], 120), // Exercise HR
        ([0x00, 180], 180), // Max exercise HR
      ];

      for (final testCase in testCases) {
        final data = testCase[0] as List<int>;
        final expected = testCase[1] as int;
        final result = HeartRateParser.parseHeartRate(data);
        expect(result, expected);
      }
    });

    test('verifies little-endian byte order for 16-bit values within range', () {
      // Test specific little-endian scenarios within valid heart rate range (30-220)
      final testCases = [
        // [flags, low_byte, high_byte] = expected_value
        ([0x01, 0x1E, 0x00], 30),    // 0x001E = 30 (minimum)
        ([0x01, 0x50, 0x00], 80),    // 0x0050 = 80
        ([0x01, 0x78, 0x00], 120),   // 0x0078 = 120
        ([0x01, 0xDC, 0x00], 220),   // 0x00DC = 220 (maximum)
      ];

      for (final testCase in testCases) {
        final data = testCase[0] as List<int>;
        final expected = testCase[1] as int;
        final result = HeartRateParser.parseHeartRate(data);
        expect(result, expected, reason: 'Failed for data: $data');
      }
    });

    test('preserves flags parsing behavior for edge cases', () {
      // Test various flag combinations to ensure robustness
      final testCases = [
        // Only bit 0 matters for HR format, other bits can be set
        ([0x02, 90], 90),   // Other flags set, still 8-bit
        ([0x04, 95], 95),   // Other flags set, still 8-bit
        ([0x03, 0x64, 0x00], 100), // Bit 0 set + other flags, 16-bit
        ([0x05, 0x78, 0x00], 120), // Multiple flags with 16-bit
      ];

      for (final testCase in testCases) {
        final data = testCase[0] as List<int>;
        final expected = testCase[1] as int;
        final result = HeartRateParser.parseHeartRate(data);
        expect(result, expected, reason: 'Failed for flags test: $data');
      }
    });

    test('validates error messages are descriptive', () {
      try {
        HeartRateParser.parseHeartRate([]);
        fail('Should have thrown BleDataParsingException');
      } on BleDataParsingException catch (e) {
        expect(e.message, contains('heart rate data'));
        expect(e.message, isNotEmpty);
      }

      try {
        HeartRateParser.parseHeartRate([0x01]);
        fail('Should have thrown BleDataParsingException');
      } on BleDataParsingException catch (e) {
        expect(e.message, contains('Insufficient data'));
        expect(e.message, isNotEmpty);
      }
    });

    test('tryParseHeartRate returns null on error', () {
      // Test that tryParseHeartRate handles errors gracefully
      expect(HeartRateParser.tryParseHeartRate([]), isNull);
      expect(HeartRateParser.tryParseHeartRate([0x00]), isNull);
      expect(HeartRateParser.tryParseHeartRate([0x00, 25]), isNull); // Out of range

      // Test valid data
      expect(HeartRateParser.tryParseHeartRate([0x00, 80]), 80);
    });

    test('isValidHeartRateData validates correctly', () {
      // Test invalid data
      expect(HeartRateParser.isValidHeartRateData([]), isFalse);
      expect(HeartRateParser.isValidHeartRateData([0x00]), isFalse);
      expect(HeartRateParser.isValidHeartRateData([0x00, 25]), isFalse); // Out of range

      // Test valid data
      expect(HeartRateParser.isValidHeartRateData([0x00, 80]), isTrue);
      expect(HeartRateParser.isValidHeartRateData([0x01, 0x50, 0x00]), isTrue); // 16-bit
    });

    test('getSensorContactStatus parses correctly', () {
      // Test sensor contact not supported
      expect(HeartRateParser.getSensorContactStatus([0x00, 80]), isNull);

      // Test sensor contact supported but not detected
      expect(HeartRateParser.getSensorContactStatus([0x02, 80]), isFalse);

      // Test sensor contact supported and detected
      expect(HeartRateParser.getSensorContactStatus([0x06, 80]), isTrue);

      // Test empty data
      expect(HeartRateParser.getSensorContactStatus([]), isNull);
    });

    test('hasEnergyExpended detects correctly', () {
      // Test energy expended not present
      expect(HeartRateParser.hasEnergyExpended([0x00, 80]), isFalse);

      // Test energy expended present
      expect(HeartRateParser.hasEnergyExpended([0x08, 80]), isTrue);

      // Test empty data
      expect(HeartRateParser.hasEnergyExpended([]), isFalse);
    });

    test('hasRRInterval detects correctly', () {
      // Test RR-Interval not present
      expect(HeartRateParser.hasRRInterval([0x00, 80]), isFalse);

      // Test RR-Interval present
      expect(HeartRateParser.hasRRInterval([0x10, 80]), isTrue);

      // Test empty data
      expect(HeartRateParser.hasRRInterval([]), isFalse);
    });
  });
}