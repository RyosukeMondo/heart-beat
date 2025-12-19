import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../ble/ble_service.dart';
import '../ble/ble_types.dart';
import '../workout/coaching_controller.dart';
import '../workout/coaching_state.dart';
import '../workout/workout_settings.dart';
import '../workout/session_summary_sheet.dart';
import '../workout/session_repository.dart';

class CoachingControls extends ConsumerWidget {
  final CoachingController controller;
  final CoachingState state;
  final BleService bleService;

  const CoachingControls({
    super.key,
    required this.controller,
    required this.state,
    required this.bleService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<BleConnectionState>(
      stream: bleService.connectionStateStream,
      initialData: BleConnectionState.idle,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? BleConnectionState.idle;

        if (connState == BleConnectionState.connected) {
          return _buildConnectedState(context, ref);
        } else if (connState == BleConnectionState.scanning ||
            connState == BleConnectionState.connecting) {
          return const Center(child: CircularProgressIndicator());
        } else {
          return _buildDisconnectedState(context);
        }
      },
    );
  }

  Widget _buildConnectedState(BuildContext context, WidgetRef ref) {
    if (state.status == SessionStatus.idle) {
      return FloatingActionButton.extended(
        onPressed: () {
          controller.startSession();
        },
        label: const Text('START SESSION'),
        icon: const Icon(Icons.play_arrow),
      );
    } else if (state.status == SessionStatus.paused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            onPressed: () => controller.resumeSession(),
            label: const Text('RESUME'),
            icon: const Icon(Icons.play_arrow),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          const SizedBox(width: 24),
          FloatingActionButton.extended(
            onPressed: () => _endSession(context, ref),
            label: const Text('STOP'),
            icon: const Icon(Icons.stop),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            onPressed: () => controller.pauseSession(),
            label: const Text('PAUSE'),
            icon: const Icon(Icons.pause),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ],
      );
    }
  }

  Widget _buildDisconnectedState(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        try {
          await bleService.scanAndConnect();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Connection failed: $e')));
          }
        }
      },
      label: const Text('CONNECT SENSOR'),
      icon: const Icon(Icons.bluetooth_searching),
    );
  }

  void _endSession(BuildContext context, WidgetRef ref) {
    controller.pauseSession();
    final currentState = controller.state;
    final startTime = currentState.sessionStartTime ?? DateTime.now();
    final endTime = DateTime.now();

    // Show summary
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SessionSummarySheet(
        session: SessionRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          start: startTime,
          end: endTime,
          avgBpm: currentState.avgBpm,
          maxBpm: currentState.maxBpm,
          minutesInZone: currentState.sessionMinutes,
          rpe: null,
        ),
        onSave: (rpe) async {
          final session = SessionRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            start: startTime,
            end: endTime,
            avgBpm: currentState.avgBpm,
            maxBpm: currentState.maxBpm,
            minutesInZone: currentState.sessionMinutes,
            rpe: rpe,
          );

          final repo = ref.read(sessionRepositoryProvider);
          await repo.saveSession(session);
          
          controller.stopSession();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('セッションが保存されました'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}
