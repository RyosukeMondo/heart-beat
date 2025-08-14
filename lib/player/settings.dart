import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerSettings extends ChangeNotifier {
  int pauseBelow;      // BPM below this -> pause
  int normalHigh;      // up to this -> 1.0x
  int linearHigh;      // from normalHigh..linearHigh -> 1.0..2.0x
  double emaAlpha;     // 0<alpha<=1, higher = more reactive
  int hysteresisBpm;   // +/- bpm to avoid thrashing around boundaries

  PlayerSettings({
    this.pauseBelow = 80,
    this.normalHigh = 120,
    this.linearHigh = 140,
    this.emaAlpha = 0.3,
    this.hysteresisBpm = 3,
  });

  // Keys for persistence
  static const _kPauseBelow = 'settings.pauseBelow';
  static const _kNormalHigh = 'settings.normalHigh';
  static const _kLinearHigh = 'settings.linearHigh';
  static const _kEmaAlpha = 'settings.emaAlpha';
  static const _kHyst = 'settings.hysteresisBpm';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    pauseBelow = p.getInt(_kPauseBelow) ?? pauseBelow;
    normalHigh = p.getInt(_kNormalHigh) ?? normalHigh;
    linearHigh = p.getInt(_kLinearHigh) ?? linearHigh;
    emaAlpha = p.getDouble(_kEmaAlpha) ?? emaAlpha;
    hysteresisBpm = p.getInt(_kHyst) ?? hysteresisBpm;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kPauseBelow, pauseBelow);
    await p.setInt(_kNormalHigh, normalHigh);
    await p.setInt(_kLinearHigh, linearHigh);
    await p.setDouble(_kEmaAlpha, emaAlpha);
    await p.setInt(_kHyst, hysteresisBpm);
  }

  Future<void> update({
    int? pauseBelow,
    int? normalHigh,
    int? linearHigh,
    double? emaAlpha,
    int? hysteresisBpm,
  }) async {
    if (pauseBelow != null) this.pauseBelow = pauseBelow;
    if (normalHigh != null) this.normalHigh = normalHigh;
    if (linearHigh != null) this.linearHigh = linearHigh;
    if (emaAlpha != null) this.emaAlpha = emaAlpha;
    if (hysteresisBpm != null) this.hysteresisBpm = hysteresisBpm;
    await _save();
    notifyListeners();
  }
}
