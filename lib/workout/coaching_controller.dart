import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ble/ble_service.dart';
import '../ble/ble_types.dart';
import 'coaching_state.dart';
import 'dart:math';

// Assuming we will have a provider for BleService
final bleServiceProvider = Provider<BleService>((ref) => BleService());

final coachingControllerProvider = StateNotifierProvider<CoachingController, CoachingState>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return CoachingController(bleService);
});

class CoachingController extends StateNotifier<CoachingState> {
  final BleService _bleService;
  StreamSubscription<int>? _heartRateSubscription;
  StreamSubscription<BleConnectionState>? _connectionStateSubscription;
  Timer? _minuteAccumulatorTimer;
  Timer? _lastSampleTimer;
  DateTime? _lastHeartRateTime;

  static const String _kDailyMinutes = 'coaching.dailyMinutes';
  static const String _kLastDate = 'coaching.lastDate';

  CoachingController(this._bleService) : super(CoachingState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadDailyProgress();

    // Listen to heart rate stream
    _heartRateSubscription = _bleService.heartRateStream.listen((bpm) {
      _onHeartRate(bpm);
    });

    // Listen to connection state
    _connectionStateSubscription = _bleService.connectionStateStream.listen((connState) {
      if (connState == BleConnectionState.disconnected || connState == BleConnectionState.error) {
         if (state.status == SessionStatus.running) {
            state = state.copyWith(reconnecting: true, status: SessionStatus.paused);
         } else {
             state = state.copyWith(reconnecting: true);
         }
      } else if (connState == BleConnectionState.connected) {
         if (state.reconnecting) {
            if (state.status == SessionStatus.paused && state.reconnecting) {
               state = state.copyWith(reconnecting: false, status: SessionStatus.running);
            } else {
               state = state.copyWith(reconnecting: false);
            }
         }
      }
    });

    // Timer to track time since last sample
    _lastSampleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastHeartRateTime != null) {
        state = state.copyWith(lastSampleAgo: DateTime.now().difference(_lastHeartRateTime!));
      }
    });

    // Timer to accumulate minutes in zone
    _minuteAccumulatorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == SessionStatus.running && !state.reconnecting && _isInZone(state.currentBpm)) {
        _secondsInZone++;
        if (_secondsInZone >= 60) {
          final newDaily = state.dailyMinutes + 1;
          state = state.copyWith(
             dailyMinutes: newDaily,
             sessionMinutes: state.sessionMinutes + 1
          );
          _saveDailyProgress(newDaily);
          _secondsInZone = 0;
        }
      }
    });
  }

  int _secondsInZone = 0;

  Future<void> _loadDailyProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_kLastDate);
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    if (lastDateStr == todayStr) {
      final savedMinutes = prefs.getInt(_kDailyMinutes) ?? 0;
      state = state.copyWith(dailyMinutes: savedMinutes);
    } else {
      // New day, reset
      await prefs.setString(_kLastDate, todayStr);
      await prefs.setInt(_kDailyMinutes, 0);
      state = state.copyWith(dailyMinutes: 0);
    }
  }

  Future<void> _saveDailyProgress(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    await prefs.setString(_kLastDate, todayStr);
    await prefs.setInt(_kDailyMinutes, minutes);
  }

  void _onHeartRate(int bpm) {
    if (bpm < 20 || bpm > 300) return; // Filter invalid BPM

    _lastHeartRateTime = DateTime.now();

    ZoneCue cue;
    if (bpm < state.targetLowerBpm) {
      cue = ZoneCue.up;
    } else if (bpm > state.targetUpperBpm) {
      cue = ZoneCue.down;
    } else {
      cue = ZoneCue.keep;
    }

    // Update metrics if session is active (running)
    int maxBpm = state.maxBpm;
    int totalBpmSum = state.totalBpmSum;
    int totalSamples = state.totalSamples;

    if (state.status == SessionStatus.running) {
      maxBpm = max(maxBpm, bpm);
      totalBpmSum += bpm;
      totalSamples++;
    }

    state = state.copyWith(
      currentBpm: bpm,
      cue: cue,
      lastSampleAgo: Duration.zero,
      maxBpm: maxBpm,
      totalBpmSum: totalBpmSum,
      totalSamples: totalSamples,
    );
  }

  bool _isInZone(int bpm) {
    return bpm >= state.targetLowerBpm && bpm <= state.targetUpperBpm;
  }

  void startSession(int targetMinutes, int lowerBpm, int upperBpm) {
     _secondsInZone = 0;
     state = state.copyWith(
       targetMinutes: targetMinutes,
       targetLowerBpm: lowerBpm,
       targetUpperBpm: upperBpm,
       sessionMinutes: 0,
       status: SessionStatus.running,
       reconnecting: false,
       maxBpm: 0,
       totalBpmSum: 0,
       totalSamples: 0,
     );
  }

  void pauseSession() {
    state = state.copyWith(status: SessionStatus.paused);
  }

  void resumeSession() {
    state = state.copyWith(status: SessionStatus.running);
  }

  void stopSession() {
     state = state.copyWith(status: SessionStatus.idle);
  }

  Future<void> resetDay() async {
    _secondsInZone = 0;
    state = state.copyWith(dailyMinutes: 0);
    await _saveDailyProgress(0);
  }

  @override
  void dispose() {
    _heartRateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _minuteAccumulatorTimer?.cancel();
    _lastSampleTimer?.cancel();
    super.dispose();
  }
}
