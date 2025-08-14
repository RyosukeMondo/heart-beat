import 'dart:typed_data';

/// Bluetooth SIG Heart Rate Measurement (UUID 0x2A37) parser
/// Returns BPM as int, or null if payload invalid.
int? parseHeartRate(List<int> data) {
  if (data.isEmpty) return null;
  final bytes = Uint8List.fromList(data);
  final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

  final flags = bd.getUint8(0);
  final isUint16 = (flags & 0x01) == 0x01;

  if (isUint16) {
    if (bytes.lengthInBytes < 3) return null;
    return bd.getUint16(1, Endian.little);
  } else {
    if (bytes.lengthInBytes < 2) return null;
    return bd.getUint8(1);
  }
}
