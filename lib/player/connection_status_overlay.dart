import 'package:flutter/material.dart';

class ConnectionStatusOverlay extends StatelessWidget {
  final bool isConnected;
  final String? deviceName;
  final double? playbackRate;
  final bool isReady;

  const ConnectionStatusOverlay({
    super.key,
    required this.isConnected,
    this.deviceName,
    this.playbackRate,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected ? Colors.blue : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: isConnected ? Colors.blue : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (deviceName != null) ...[
              const SizedBox(height: 4),
              Text(
                deviceName!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rate: ${playbackRate?.toStringAsFixed(2) ?? '--'}x',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isReady ? 'Ready' : 'Loading...',
                  style: TextStyle(
                    color: isReady ? Colors.green : Colors.orange,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
