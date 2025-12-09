import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'webview_content.dart';

class PlayerWebView extends StatelessWidget {
  final TextEditingController urlController;
  final bool ytReady;
  final Function(InAppWebViewController) onWebViewCreated;
  final Function(bool) onReadyChanged;
  final Function(double) onRateChanged;
  final Function(int) onStateChanged;
  final Function(int) onError;
  final Function(String) onLog;
  final VoidCallback onReportRate;

  const PlayerWebView({
    super.key,
    required this.urlController,
    required this.ytReady,
    required this.onWebViewCreated,
    required this.onReadyChanged,
    required this.onRateChanged,
    required this.onStateChanged,
    required this.onError,
    required this.onLog,
    required this.onReportRate,
  });

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: playerHtmlContent,
        baseUrl: WebUri('https://localhost/'),
      ),
      onWebViewCreated: (c) {
        onWebViewCreated(c);
        _setupJsHandlers(c);
        Future.delayed(const Duration(seconds: 3), () {
          if (!ytReady) {
            _evalJsUnchecked(c,
              "(function(){ try{ var ok=(typeof YT!=='undefined'&&typeof player!=='undefined'&&player&&typeof player.getPlaybackRate==='function'); if(ok){ window.flutter_inappwebview.callHandler('yt_ready'); if (typeof reportRate==='function'){ reportRate(); } } }catch(e){} })();",
            );
          }
        });
      },
      shouldOverrideUrlLoading: (controller, navAction) async {
        final isMain = navAction.isForMainFrame;
        final uri = navAction.request.url;
        if (!isMain || uri == null) return NavigationActionPolicy.ALLOW;
        final scheme = uri.scheme;
        if (scheme == 'about' || scheme == 'data') {
          return NavigationActionPolicy.ALLOW;
        }
        final url = uri.toString();
        final id = _extractVideoId(url);
        if (id != null) {
          onLog('[WebView] Intercept nav -> cue $id');
          _evalJsUnchecked(controller,
            "(function(){ try{ if (typeof cueVideoByIdX==='function'){ cueVideoByIdX('$id'); } else { window.__pendingId='$id'; } if (typeof reportRate==='function'){ reportRate(); } }catch(e){} })();",
          );
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onLoadStart: (controller, url) {
        onReadyChanged(false);
      },
      onLoadStop: (controller, url) {
        _evalJsUnchecked(controller,
          "(function(){ try{ var ok=(typeof YT!=='undefined'&&typeof player!=='undefined'&&player&&typeof player.getPlaybackRate==='function'); if(ok){ window.flutter_inappwebview.callHandler('yt_ready'); if (typeof reportRate==='function'){ reportRate(); } } }catch(e){} })();",
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
    );
  }

  void _setupJsHandlers(InAppWebViewController c) {
    c.addJavaScriptHandler(
      handlerName: 'yt_ready',
      callback: (args) {
        onLog('[WebView] yt_ready (Dart handler)');
        onReadyChanged(true);
        final id = _extractVideoId(urlController.text);
        if (id != null) {
          _evalJsUnchecked(c,
            "(function(){ if (typeof cueVideoByIdX==='function'){ cueVideoByIdX('$id'); } })();",
          );
        }
        _evalJsUnchecked(c,
          "(function(){ if (typeof reportRate==='function'){ reportRate(); } })();",
        );
        return [];
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'yt_rate',
      callback: (args) {
        if (args.isNotEmpty) {
          final v = (args.first as num).toDouble();
          onRateChanged(v);
        }
        return [];
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'yt_state',
      callback: (args) {
        if (args.isNotEmpty) {
          final st = (args.first as num).toInt();
          onStateChanged(st);
        }
        return [];
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'yt_error',
      callback: (args) {
        if (args.isNotEmpty) {
          final code = (args.first as num).toInt();
          onError(code);
        }
        return [];
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'yt_log',
      callback: (args) {
        if (args.isNotEmpty) {
          onLog('[WebView][yt_log] ${args.first}');
        }
        return [];
      },
    );
  }

  Future<void> _evalJsUnchecked(InAppWebViewController c, String code) async {
    try {
      await c.evaluateJavascript(source: code);
    } catch (_) {}
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
