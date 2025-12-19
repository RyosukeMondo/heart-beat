import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;

import '../ble/ble_service.dart';
import 'settings.dart';
import '../workout/coaching_controller.dart';
import 'heart_rate_overlay.dart';
import 'connection_status_overlay.dart';
import 'player_controls.dart';
import 'player_webview.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});
  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  InAppWebViewController? _web;
  double? _ema;
  int? _lastAppliedBpm;
  final TextEditingController _urlCtl = TextEditingController(
    text: 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
  );
  double? _currentPlaybackRate;
  bool _ytReady = false;
  int? _ytState;
  int? _ytError;

  int? _currentBpm;
  bool _bleConnected = false;
  String? _deviceName;
  DateTime? _lastHeartRateUpdate;
  bool _showOverlay = true;

  bool _debugLog = true;
  void Function(String? message, {int? wrapWidth})? _origDebugPrint;

  void _applyDebugLog() {
    if (_debugLog) {
      if (_origDebugPrint != null) {
        debugPrint = _origDebugPrint!;
        _origDebugPrint = null;
      }
    } else {
      if (_origDebugPrint == null) {
        _origDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {};
      }
    }
  }

  Future<void> _evalJs(String code) async {
    if (!_ytReady || _web == null) return;
    try {
      await _web!.evaluateJavascript(source: code);
    } catch (_) {}
  }

  Future<void> _evalJsUnchecked(String code) async {
    if (_web == null) return;
    try {
      await _web!.evaluateJavascript(source: code);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ytReady = false;
    if (_origDebugPrint != null) {
      debugPrint = _origDebugPrint!;
      _origDebugPrint = null;
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkConnectionStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerSettings = ref.watch(playerSettingsProvider);
    final coachingState = ref.watch(coachingControllerProvider);
    _applyDebugLog();

    // Listen to coaching state for playback rate updates
    ref.listen<CoachingState>(coachingControllerProvider, (prev, next) {
      if (next.currentBpm > 0) {
        _onBpm(next.currentBpm, playerSettings);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube x Heart Rate'),
        actions: [
          IconButton(
            icon: Icon(_showOverlay ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showOverlay = !_showOverlay),
            tooltip: 'Toggle Overlay',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                PlayerWebView(
                  urlController: _urlCtl,
                  ytReady: _ytReady,
                  onWebViewCreated: (c) => _web = c,
                  onReadyChanged: (ready) {
                    if (mounted) setState(() => _ytReady = ready);
                  },
                  onRateChanged: (rate) {
                    if (mounted) setState(() => _currentPlaybackRate = rate);
                  },
                  onStateChanged: (state) {
                    if (mounted) setState(() => _ytState = state);
                  },
                  onError: (code) {
                    if (mounted) setState(() => _ytError = code);
                  },
                  onLog: (msg) => debugPrint(msg),
                  onReportRate: () {
                    _evalJs(
                      "(function(){ if (typeof reportRate==='function'){ reportRate(); } })();",
                    );
                  },
                ),
                if (_showOverlay) ...[
                  // New ZoneMeter overlay (mini version)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _buildMiniZoneMeter(coachingState),
                  ),
                  // DailyChargeBar overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: const DailyChargeBar(),
                    ),
                  ),
                  ConnectionStatusOverlay(
                    isConnected: coachingState.currentBpm > 0 && !coachingState.reconnecting,
                    deviceName: _deviceName,
                    playbackRate: _currentPlaybackRate,
                    isReady: _ytReady,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          PlayerControls(
            urlController: _urlCtl,
            onLoad: _onLoadUrl,
            onReport: () {
              _evalJs(
                "(function(){ if (typeof reportRate==='function'){ reportRate(); } })();",
              );
            },
            currentBpm: coachingState.currentBpm,
            ema: _ema,
            playbackRate: _currentPlaybackRate,
            isReady: _ytReady,
            ytState: _ytState,
            ytError: _ytError,
            debugLog: _debugLog,
            onDebugLogChanged: (v) {
              setState(() {
                _debugLog = v;
                _applyDebugLog();
              });
            },
            showOverlay: _showOverlay,
            onShowOverlayChanged: (v) => setState(() => _showOverlay = v),
            playerSettings: playerSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniZoneMeter(CoachingState state) {
    Color color;
    IconData icon;
    switch (state.cue) {
      case ZoneCue.up:
        color = Colors.blue;
        icon = Icons.arrow_upward;
        break;
      case ZoneCue.keep:
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case ZoneCue.down:
        color = Colors.red;
        icon = Icons.arrow_downward;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.currentBpm} BPM',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                state.cue.name.toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onBpm(int bpm, PlayerSettings s) {
    if (!mounted) return;
    
    setState(() {
      _currentBpm = bpm;
      _bleConnected = true;
      _lastHeartRateUpdate = DateTime.now();
    });
    
    if (!_ytReady) {
      debugPrint('[BPM] ytReady=N skip bpm=$bpm');
      return;
    }

    final alpha = s.emaAlpha.clamp(0.05, 1.0);
    _ema = (_ema == null) ? bpm.toDouble() : (alpha * bpm + (1 - alpha) * _ema!);
    final smoothed = _ema!.round();

    final lastBpm = _lastAppliedBpm;
    final crossedPauseBoundary =
        lastBpm != null &&
        ((lastBpm >= s.pauseBelow && smoothed < s.pauseBelow) ||
            (lastBpm < s.pauseBelow && smoothed >= s.pauseBelow));

    if (smoothed < s.pauseBelow) {
      _lastAppliedBpm = smoothed;
      _evalJs(
        "(function(){ if (typeof pauseVideo==='function'){ pauseVideo(); } })();",
      );
      return;
    }

    if (!crossedPauseBoundary &&
        lastBpm != null &&
        (smoothed - lastBpm).abs() < s.hysteresisBpm) {
      return;
    }
    _lastAppliedBpm = smoothed;

    final target = _mapBpmToRate(smoothed, s);
    if (target <= 0) {
      _evalJs(
        "(function(){ if (typeof pauseVideo==='function'){ pauseVideo(); } })();",
      );
    } else {
      final rate = target.toStringAsFixed(3);
      _evalJs(
        "(function(){ if (typeof setRate==='function'){ setRate($rate); } })();",
      );
      if (_ytState != 1) {
        _evalJs(
          "(function(){ if (typeof playVideo==='function'){ playVideo(); } })();",
        );
      }
    }
  }

  double _mapBpmToRate(int bpm, PlayerSettings s) {
    if (bpm < s.pauseBelow) return 0.0;
    if (bpm <= s.normalHigh) return 1.0;
    final low = s.normalHigh;
    final high = s.linearHigh;
    if (bpm >= high) return 2.0;
    final t = (bpm - low) / (high - low);
    return 1.0 + t.clamp(0, 1);
  }

  void _checkConnectionStatus() {
    if (_lastHeartRateUpdate != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastHeartRateUpdate!);
      if (timeSinceLastUpdate.inSeconds > 10) {
        setState(() {
          _bleConnected = false;
          _deviceName = null;
        });
      }
    }
  }

  void _onLoadUrl() {
    final id = _extractVideoId(_urlCtl.text);
    if (id != null) {
      debugPrint('[UI] Load pressed -> $id');
      _evalJsUnchecked(
        "(function(){ try{ if (typeof setPendingId==='function'){ setPendingId('$id'); } else { window.__pendingId='$id'; } if (typeof cueVideoByIdX==='function'){ cueVideoByIdX('$id'); } }catch(e){} })();",
      );
    } else {
      debugPrint(
        '[UI] Load pressed -> no valid video id from: ${_urlCtl.text}',
      );
    }
  }

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      if (uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == 'embed' &&
          uri.pathSegments.length >= 2) {
        return uri.pathSegments[1];
      }
    } catch (_) {}
    return null;
  }
}
