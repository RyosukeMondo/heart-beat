import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import 'settings.dart';
import '../workout/workout_settings.dart';
import '../workout/coaching_controller.dart'; // Import for bleServiceProvider

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});
  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  InAppWebViewController? _web;
  double? _ema; // smoothed bpm
  int? _lastAppliedBpm; // for BPM-based hysteresis
  final TextEditingController _urlCtl = TextEditingController(
    text: 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
  );
  double? _currentPlaybackRate;
  bool _ytReady = false; // IFrame player ready
  int? _ytState; // YouTube player state
  int? _ytError; // last onError code

  // Heart rate monitoring enhancements
  int? _currentBpm;
  bool _bleConnected = false;
  String? _deviceName;
  DateTime? _lastHeartRateUpdate;
  bool _showOverlay = true;

  // Debug logging flag
  bool _debugLog = true;
  void Function(String? message, {int? wrapWidth})? _origDebugPrint;

  void _applyDebugLog() {
    // Override Flutter's global debugPrint to silence logs when disabled
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

  // For JS snippets that are safe to run before player ready (e.g., set pending video ID)
  Future<void> _evalJsUnchecked(String code) async {
    if (_web == null) return;
    try {
      await _web!.evaluateJavascript(source: code);
    } catch (_) {}
  }

  Future<void> _evalJs(String code) async {
    if (!_ytReady || _web == null) return;
    try {
      await _web!.evaluateJavascript(source: code);
    } catch (_) {
      // ignore evaluation errors, typically due to navigation timing
    }
  }

  @override
  void dispose() {
    _ytReady = false;
    // Restore debugPrint if we modified it
    if (_origDebugPrint != null) {
      debugPrint = _origDebugPrint!;
      _origDebugPrint = null;
    }
    super.dispose();
  }

  void _onBpm(int bpm, PlayerSettings s) {
    if (!mounted) {
      return;
    }
    
    // Update heart rate monitoring state
    setState(() {
      _currentBpm = bpm;
      _bleConnected = true;
      _lastHeartRateUpdate = DateTime.now();
    });
    
    if (!_ytReady) {
      debugPrint('[BPM] ytReady=N skip bpm=$bpm');
      return;
    }
    // EMA smoothing
    final alpha = s.emaAlpha.clamp(0.05, 1.0);
    final prevEma = _ema;
    _ema =
        (_ema == null) ? bpm.toDouble() : (alpha * bpm + (1 - alpha) * _ema!);
    final smoothed = _ema!.round();
    debugPrint(
      '[BPM] raw=$bpm prevEma=${prevEma?.toStringAsFixed(2) ?? 'null'} alpha=${alpha.toStringAsFixed(2)} ema=${_ema!.toStringAsFixed(2)} smoothed=$smoothed',
    );

    // Settings snapshot and boundary detection
    debugPrint(
      '[BPM] settings: pause<${s.pauseBelow} normalHigh=${s.normalHigh} linearHigh=${s.linearHigh} emaAlpha=${s.emaAlpha.toStringAsFixed(2)} hysteresis=${s.hysteresisBpm}',
    );
    final lastBpm = _lastAppliedBpm;
    final crossedPauseBoundary =
        lastBpm != null &&
        ((lastBpm >= s.pauseBelow && smoothed < s.pauseBelow) ||
            (lastBpm < s.pauseBelow && smoothed >= s.pauseBelow));
    if (crossedPauseBoundary) {
      debugPrint(
        '[BPM] crossed pause boundary: last=$lastBpm -> now=$smoothed (pause<${s.pauseBelow})',
      );
    }

    // Pause rule has priority: apply immediately before any hysteresis hold
    if (smoothed < s.pauseBelow) {
      _lastAppliedBpm = smoothed;
      debugPrint(
        '[BPM] action: pause (smoothed=$smoothed < pause<${s.pauseBelow})',
      );
      _evalJs(
        "(function(){ if (typeof pauseVideo==='function'){ pauseVideo(); } })();",
      );
      return;
    }

    // Hysteresis on small fluctuations, but DO NOT hold if crossing pause boundary
    if (!crossedPauseBoundary &&
        lastBpm != null &&
        (smoothed - lastBpm).abs() < s.hysteresisBpm) {
      debugPrint(
        '[BPM] hysteresis hold: last=$lastBpm smoothed=$smoothed Δ=${(smoothed - lastBpm).abs()} < ${s.hysteresisBpm}',
      );
      return; // small change: ignore to prevent thrashing
    }
    _lastAppliedBpm = smoothed;

    // Otherwise compute and apply rate
    final target = _mapBpmToRate(smoothed, s);
    debugPrint('[BPM] mapped target=${target.toStringAsFixed(3)}');
    if (target <= 0) {
      debugPrint('[BPM] action: pause via target<=0');
      _evalJs(
        "(function(){ if (typeof pauseVideo==='function'){ pauseVideo(); } })();",
      );
    } else {
      final rate = target.toStringAsFixed(3);
      debugPrint('[BPM] action: setRate ${rate}x');
      _evalJs(
        "(function(){ if (typeof setRate==='function'){ setRate($rate); } })();",
      );
      // If paused or not playing, request play
      if (_ytState != 1) {
        debugPrint(
          '[BPM] action: play (state=${_ytState?.toString() ?? 'null'})',
        );
        _evalJs(
          "(function(){ if (typeof playVideo==='function'){ playVideo(); } })();",
        );
      }
    }
  }

  double _mapBpmToRate(int bpm, PlayerSettings s) {
    if (bpm < s.pauseBelow) return 0.0; // pause
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
        // Consider disconnected if no updates for 10 seconds
        setState(() {
          _bleConnected = false;
          _deviceName = null;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Check connection status periodically
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
    // Note: Provider.of/context.watch works for standard providers,
    // but mixing with Riverpod usually requires ConsumerWidget/ConsumerState.
    // Assuming context.watch<PlayerSettings>() comes from package:provider.
    final settings = context.watch<PlayerSettings>();
    // Ensure current debug flag is applied
    _applyDebugLog();

    final html = '''
<!doctype html><html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>
  html, body { height: 100%; margin: 0; background: #000; }
  #player { position: fixed; inset: 0; width: 100vw; height: 100vh; }
</style>
</head>
<body>
<div id="player"></div>
<script>
// Boot diagnostics
try{ if(window.flutter_inappwebview && window.flutter_inappwebview.callHandler){ window.flutter_inappwebview.callHandler('yt_log','boot: start href='+location.href); } }catch(_){ }
window.addEventListener('error', function(e){ try{ window.flutter_inappwebview.callHandler('yt_log','window.error: '+(e && e.message ? e.message : 'unknown')); }catch(_){ } });
// Ensure the IFrame API is present; attempt several times if missing
var __ytInjectTries = 0;
function injectYT(){
  try{
    if (typeof YT==='undefined' || typeof YT.Player==='undefined'){
      __ytInjectTries++;
      var s=document.createElement('script');
      s.src='https://www.youtube.com/iframe_api';
      s.onerror=function(){ try{ window.flutter_inappwebview.callHandler('yt_log','iframe_api load error (try '+__ytInjectTries+')'); }catch(_){ } };
      s.onload=function(){ try{ window.flutter_inappwebview.callHandler('yt_log','iframe_api loaded (try '+__ytInjectTries+')'); }catch(_){ } };
      document.head.appendChild(s);
    }
  }catch(e){ try{ window.flutter_inappwebview.callHandler('yt_log','injectYT exception: '+e); }catch(_){ } }
}
injectYT();
var __probeCount=0;
var __probeTimer=setInterval(function(){
  __probeCount++;
  try{
    var ytt=typeof YT, plt=typeof player;
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler){ window.flutter_inappwebview.callHandler('yt_log','probe@html#'+__probeCount+': YT='+ytt+' player='+plt); }
  }catch(_){ }
  if (__probeCount<=5){ injectYT(); }
  if (__probeCount>=15){ clearInterval(__probeTimer); }
}, 1000);
</script>
<script>
var player, fallback=[0.5,1,1.25,1.5,2];
function onYouTubeIframeAPIReady(){
  try{ window.flutter_inappwebview.callHandler('yt_log','onYouTubeIframeAPIReady'); }catch(_){ }
  player=new YT.Player('player',{
    height: '100%', width: '100%', videoId:'',
    playerVars:{controls:1, rel:0, enablejsapi:1},
    host:'https://www.youtube.com',
    events:{
      onReady:()=>{ try{ if(window.__pendingId){ try{ window.flutter_inappwebview.callHandler('yt_log', 'onReady consume pendingId='+window.__pendingId); }catch(_){}; player.cueVideoById(window.__pendingId); } }catch(e){}; window.flutter_inappwebview.callHandler('yt_ready'); reportRate(); },
      onStateChange:(e)=>{ try{ window.flutter_inappwebview.callHandler('yt_state', e.data); reportRate(); }catch(_){} },
      onError:(e)=>{ try{ window.flutter_inappwebview.callHandler('yt_log', 'onError '+JSON.stringify(e)); window.flutter_inappwebview.callHandler('yt_error', e.data); }catch(_){} }
    }
  });
  window.pauseVideo = function(){
    try{
      var beforeState = (player&&player.getPlayerState)?player.getPlayerState():null;
      try{ window.flutter_inappwebview.callHandler('yt_log','pauseVideo() before state='+beforeState); }catch(_){ }
      if(player && typeof player.pauseVideo==='function'){ player.pauseVideo(); }
      setTimeout(function(){
        var afterState = (player&&player.getPlayerState)?player.getPlayerState():null;
        try{ window.flutter_inappwebview.callHandler('yt_log','pauseVideo after state='+afterState); }catch(_){ }
      }, 250);
    }catch(e){ try{ window.flutter_inappwebview.callHandler('yt_log','pauseVideo error '+e); }catch(_){ } }
  }
  window.playVideo = function(){
    try{
      var beforeState = (player&&player.getPlayerState)?player.getPlayerState():null;
      try{ window.flutter_inappwebview.callHandler('yt_log','playVideo() before state='+beforeState); }catch(_){ }
      if(player && typeof player.playVideo==='function'){ player.playVideo(); }
      setTimeout(function(){
        var afterState = (player&&player.getPlayerState)?player.getPlayerState():null;
        try{ window.flutter_inappwebview.callHandler('yt_log','playVideo after state='+afterState); }catch(_){ }
      }, 250);
    }catch(e){ try{ window.flutter_inappwebview.callHandler('yt_log','playVideo error '+e); }catch(_){ } }
  }
}
function nearestAllowed(r){
  var ar = (player && player.getAvailablePlaybackRates)?player.getAvailablePlaybackRates():fallback;
  // choose the closest allowed <= r; fallback to 1 if none
  var under = ar.filter(x=>x<=r);
  if (under.length===0) return 1.0;
  under.sort((a,b)=>Math.abs(r-a)-Math.abs(r-b));
  return under[0];
}
function setRate(r){ if(player){ player.setPlaybackRate(nearestAllowed(r)); reportRate(); } }
function pauseVideo(){ if(player){ player.pauseVideo(); } }
function cueVideoByIdX(id){
  try{
    if(player && typeof player.cueVideoById === 'function'){
      player.cueVideoById(id);
    } else {
      try{ window.flutter_inappwebview.callHandler('yt_log', 'queue pendingId='+id+' (player not ready)'); }catch(_){};
      window.__pendingId = id;
    }
  }catch(e){ window.__pendingId = id; }
}
function setPendingId(id){ window.__pendingId = id; }
function reportRate(){ if(player){ var pr = player.getPlaybackRate?player.getPlaybackRate():null; if(pr!=null){ window.flutter_inappwebview.callHandler('yt_rate', pr); } } }
setInterval(()=>{ try{ reportRate(); }catch(e){} }, 1000);
setInterval(()=>{ try{ if(window.__pendingId && player && typeof player.cueVideoById==='function'){ try{ window.flutter_inappwebview.callHandler('yt_log', 'consume pendingId='+window.__pendingId); }catch(_){}; player.cueVideoById(window.__pendingId); window.__pendingId=null; } }catch(e){} }, 500);
</script></body></html>
''';

    return Scaffold(
      appBar: AppBar(title: const Text('YouTube x Heart Rate')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
              initialData: InAppWebViewInitialData(
                data: html,
                baseUrl: WebUri('https://localhost/'),
              ),
              onWebViewCreated: (c) {
                _web = c;
                debugPrint('[WebView] onWebViewCreated');
                c.addJavaScriptHandler(
                  handlerName: 'yt_ready',
                  callback: (args) {
                    debugPrint('[WebView] yt_ready (Dart handler)');
                    setState(() {
                      _ytReady = true;
                      final id = _extractVideoId(_urlCtl.text);
                      if (id != null) {
                        _evalJs(
                          "(function(){ if (typeof cueVideoByIdX==='function'){ cueVideoByIdX('$id'); } })();",
                        );
                      }
                      _evalJs(
                        "(function(){ if (typeof reportRate==='function'){ reportRate(); } })();",
                      );
                    });
                    c.addJavaScriptHandler(
                      handlerName: 'yt_rate',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          final v = (args.first as num).toDouble();
                          debugPrint('[WebView] yt_rate => $v');
                          if (!mounted) return [];
                          setState(() => _currentPlaybackRate = v);
                        }
                        return [];
                      },
                    );
                    c.addJavaScriptHandler(
                      handlerName: 'yt_state',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          final st = (args.first as num).toInt();
                          debugPrint('[WebView] yt_state => $st');
                          if (!mounted) return [];
                          setState(() => _ytState = st);
                        }
                        return [];
                      },
                    );
                    c.addJavaScriptHandler(
                      handlerName: 'yt_error',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          final code = (args.first as num).toInt();
                          debugPrint('[WebView][yt_error] $code');
                          if (!mounted) return [];
                          setState(() => _ytError = code);
                        }
                        return [];
                      },
                    );
                  },
                );
                c.addJavaScriptHandler(
                  handlerName: 'yt_log',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      debugPrint('[WebView][yt_log] ${args.first}');
                    }
                    return [];
                  },
                );
                // Schedule readiness probes outside of yt_ready so they run even if yt_ready never fires
                Future.delayed(const Duration(seconds: 3), () {
                  if (!mounted) return;
                  if (!_ytReady) {
                    debugPrint('[WebView] Ready still N after 3s; probing');
                    _evalJsUnchecked(
                      "(function(){ try{ var ok=(typeof YT!=='undefined'&&typeof player!=='undefined'&&player&&typeof player.getPlaybackRate==='function'); if(ok){ window.flutter_inappwebview.callHandler('yt_ready'); if (typeof reportRate==='function'){ reportRate(); } } else { try{ window.flutter_inappwebview.callHandler('yt_log','probe@3s: YT='+(typeof YT)+' player='+(typeof player)); }catch(_){} } }catch(e){} })();",
                    );
                  }
                });
                // Short-lived periodic probe (10 tries every 1s)
                int tries = 0;
                void tick() {
                  if (!mounted || _ytReady || tries >= 10) return;
                  tries++;
                  _evalJsUnchecked(
                    "(function(){ try{ var ok=(typeof YT!=='undefined'&&typeof player!=='undefined'&&player&&typeof player.getPlaybackRate==='function'); if(ok){ window.flutter_inappwebview.callHandler('yt_ready'); } else { try{ window.flutter_inappwebview.callHandler('yt_log','probe#${tries}s: YT='+(typeof YT)+' player='+(typeof player)); }catch(_){} } }catch(e){} })();",
                  );
                  Future.delayed(const Duration(seconds: 1), tick);
                }

                Future.delayed(const Duration(seconds: 1), tick);
              },
              shouldOverrideUrlLoading: (controller, navAction) async {
                // Only consider main-frame navigations; let subframes/resources load
                final isMain = navAction.isForMainFrame;
                final uri = navAction.request.url;
                if (!isMain || uri == null) return NavigationActionPolicy.ALLOW;
                final scheme = uri.scheme;
                if (scheme == 'about' || scheme == 'data') {
                  return NavigationActionPolicy.ALLOW;
                }
                final url = uri.toString();
                // Intercept YouTube navigations and keep control inside the iframe API
                final id = _extractVideoId(url);
                if (id != null) {
                  debugPrint('[WebView] Intercept nav -> cue $id');
                  _evalJsUnchecked(
                    "(function(){ try{ if (typeof cueVideoByIdX==='function'){ cueVideoByIdX('$id'); } else { window.__pendingId='$id'; } if (typeof reportRate==='function'){ reportRate(); } }catch(e){} })();",
                  );
                  return NavigationActionPolicy.CANCEL;
                }
                // Allow everything else
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (controller, url) {
                debugPrint(
                  '[WebView] onLoadStart ${url?.toString() ?? 'null'}',
                );
                _ytReady = false;
              },
              onLoadStop: (controller, url) {
                // Probe readiness in case onReady didn't fire for any reason (unchecked because _ytReady is false)
                debugPrint(
                  '[WebView] onLoadStop ${url?.toString() ?? 'null'}; probing ready',
                );
                _evalJsUnchecked(
                  "(function(){ try{ var ok=(typeof YT!=='undefined'&&typeof player!=='undefined'&&player&&typeof player.getPlaybackRate==='function'); if(ok){ window.flutter_inappwebview.callHandler('yt_ready'); if (typeof reportRate==='function'){ reportRate(); } } }catch(e){} })();",
                );
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint(
                  '[WebView] ${consoleMessage.messageLevel} ${consoleMessage.message}',
                );
              },
              onJsConfirm: (controller, jsConfirmRequest) async {
                return JsConfirmResponse(
                  handledByClient: true,
                  action: JsConfirmResponseAction.CONFIRM,
                );
              },
              onJsAlert: (controller, jsAlertRequest) async {
                debugPrint('[WebView][alert] ${jsAlertRequest.message}');
                return JsAlertResponse(
                  handledByClient: true,
                  action: JsAlertResponseAction.CONFIRM,
                );
              },
              onReceivedError: (controller, request, error) {
                debugPrint(
                  '[WebView][Error] ${error.type} ${error.description} for ${request.url}',
                );
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                debugPrint(
                  '[WebView][HTTP ${errorResponse.statusCode}] for ${request.url}',
                );
              },
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                thirdPartyCookiesEnabled: true,
                supportZoom: false,
                disableVerticalScroll: true,
                disableHorizontalScroll: true,
                transparentBackground: true,
              ),
                ),
                // Heart Rate Overlay
                if (_showOverlay) _buildHeartRateOverlay(),
                // Connection Status Overlay
                _buildConnectionStatusOverlay(),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlCtl,
                        decoration: const InputDecoration(
                          labelText: 'YouTube URL',
                          hintText:
                              'https://www.youtube.com/watch?v=... or youtu.be/...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        final id = _extractVideoId(_urlCtl.text);
                        if (id != null) {
                          // Always set pending id, then attempt immediate cue if possible
                          debugPrint('[UI] Load pressed -> $id');
                          _evalJsUnchecked(
                            "(function(){ try{ if (typeof setPendingId==='function'){ setPendingId('$id'); } else { window.__pendingId='$id'; } if (typeof cueVideoByIdX==='function'){ cueVideoByIdX('$id'); } }catch(e){} })();",
                          );
                        } else {
                          debugPrint(
                            '[UI] Load pressed -> no valid video id from: ${_urlCtl.text}',
                          );
                        }
                      },
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('Load'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        _evalJs(
                          "(function(){ if (typeof reportRate==='function'){ reportRate(); } })();",
                        );
                      },
                      child: const Text('Report'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<int>(
                  stream: ref.watch(bleServiceProvider).heartRateStream,
                  builder: (context, snap) {
                    if (snap.hasData) {
                      _onBpm(snap.data!, settings);
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('BPM: ${snap.data ?? '--'}'),
                        Text('EMA: ${_ema?.toStringAsFixed(1) ?? '--'}'),
                        Text(
                          'Rate: ${_currentPlaybackRate?.toStringAsFixed(2) ?? '--'}x',
                        ),
                        Text('Ready: ${_ytReady ? 'Y' : 'N'}'),
                        if (_ytState != null) Text('State: $_ytState'),
                      ],
                    );
                  },
                ),
                if (_ytError == 101 || _ytError == 150)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'This video cannot be embedded (error $_ytError). Try a different URL.',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Debug log'),
                  value: _debugLog,
                  onChanged: (v) {
                    setState(() {
                      _debugLog = v;
                      _applyDebugLog();
                    });
                  },
                ),
                Consumer<WorkoutSettings>(
                  builder: (context, workout, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Workout Configuration')),
                            Switch.adaptive(
                              value: _showOverlay,
                              onChanged: (value) => setState(() => _showOverlay = value),
                            ),
                            const Text('Overlay'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // Current workout display
                        if (workout.isUsingCustomConfig) ...[
                          Card(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(
                                        workout.selectedCustomConfig!.colorCode.substring(1),
                                        radix: 16,
                                      ) + 0xFF000000),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${workout.selectedCustomConfig!.name}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${workout.selectedCustomConfig!.targetZoneText} • ${workout.selectedCustomConfig!.durationText}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => workout.clearCustomWorkoutSelection(),
                                    icon: const Icon(Icons.clear),
                                    tooltip: 'Clear custom workout',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: WorkoutType.values.map((t) {
                              final selected = workout.selected == t;
                              return ChoiceChip(
                                label: Text(_labelFor(t)),
                                selected: selected,
                                onSelected: (_) async {
                                  await workout.selectWorkout(t);
                                  await workout.applyToPlayer(settings);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        
                        const SizedBox(height: 8),
                        Text(
                          'Applied thresholds: pause<${settings.pauseBelow}  1.0x≤${settings.normalHigh}  →2.0x@${settings.linearHigh}',
                          style: const TextStyle(fontSize: 11),
                        )
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                const Text('注: 動画はユーザーが再生を開始してください（自動再生制限）。'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url.trim());
      // youtu.be/<id>
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      // youtube.com/watch?v=<id>
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      // youtube.com/embed/<id>
      if (uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == 'embed' &&
          uri.pathSegments.length >= 2) {
        return uri.pathSegments[1];
      }
    } catch (_) {}
    return null;
  }

  Widget _buildHeartRateOverlay() {
    final workoutSettings = context.watch<WorkoutSettings>();
    final (lower, upper) = workoutSettings.targetRange();
    
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getHeartRateColor(lower, upper),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite,
                  color: _getHeartRateColor(lower, upper),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_currentBpm ?? '--'} BPM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_ema != null) ...[
              const SizedBox(height: 4),
              Text(
                'EMA: ${_ema!.toStringAsFixed(1)}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Target: $lower-$upper',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            if (workoutSettings.isUsingCustomConfig) ...[
              const SizedBox(height: 4),
              Text(
                workoutSettings.selectedCustomConfig!.name,
                style: TextStyle(
                  color: Color(int.parse(
                    workoutSettings.selectedCustomConfig!.colorCode.substring(1), 
                    radix: 16,
                  ) + 0xFF000000),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusOverlay() {
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
                  _bleConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: _bleConnected ? Colors.blue : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _bleConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _bleConnected ? Colors.blue : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (_deviceName != null) ...[
              const SizedBox(height: 4),
              Text(
                _deviceName!,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rate: ${_currentPlaybackRate?.toStringAsFixed(2) ?? '--'}x',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _ytReady ? 'Ready' : 'Loading...',
                  style: TextStyle(
                    color: _ytReady ? Colors.green : Colors.orange,
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

  Color _getHeartRateColor(int lower, int upper) {
    if (_currentBpm == null) return Colors.grey;
    
    if (_currentBpm! < lower) {
      return Colors.blue; // Below target zone
    } else if (_currentBpm! > upper) {
      return Colors.red; // Above target zone
    } else {
      return Colors.green; // In target zone
    }
  }

  String _labelFor(WorkoutType t) {
    switch (t) {
      case WorkoutType.recovery:
        return 'Recovery (Z1)';
      case WorkoutType.fatBurn:
        return 'Fat Burn (Z2)';
      case WorkoutType.endurance:
        return 'Endurance (Z2-3)';
      case WorkoutType.tempo:
        return 'Tempo (Z4)';
      case WorkoutType.hiit:
        return 'HIIT (Z5)';
    }
  }
}
