import 'dart:math' as math;

enum Gender { male, female, other }

class WorkoutProfile {
  final int age; // years
  final Gender gender;
  final int? restingHr; // bpm (optional, for Karvonen)
  final int intensityOffset; // % offset

  const WorkoutProfile({
    required this.age,
    required this.gender,
    this.restingHr,
    this.intensityOffset = 0,
  });

  // Max HR estimates
  int maxHr220() => (220 - age).clamp(100, 205); // simple cap for sanity
  int maxHr208() => (208 - (0.7 * age)).round().clamp(100, 205);

  int effectiveMaxHr() {
    // Favor 208 - 0.7*age per spec discussion
    return maxHr208();
  }

  // Returns lower/upper bounds for zone as bpm
  // Zone definitions based on %Max HR per specs: Z1:50-60, Z2:60-70, Z3:70-80, Z4:80-90, Z5:90-100
  Map<int, (int lower, int upper)> zonesByMax() {
    final m = effectiveMaxHr();
    final offset = intensityOffset / 100.0;
    (int, int) p(double lo, double hi) {
      final lower = (m * (lo + offset)).round();
      final upper = (m * (hi + offset)).round();
      return (lower, math.max(lower + 1, upper));
    }
    return {
      1: p(0.50, 0.60),
      2: p(0.60, 0.70),
      3: p(0.70, 0.80),
      4: p(0.80, 0.90),
      5: p(0.90, 1.00),
    };
  }

  // Karvonen method (optional) using HR reserve if restingHr provided
  Map<int, (int lower, int upper)>? zonesByKarvonen() {
    if (restingHr == null) return null;
    final r = restingHr!.clamp(30, 120);
    final max = effectiveMaxHr();
    final offset = intensityOffset / 100.0;
    // Build as with byMax but computing both bounds directly
    (int, int) pp(double lo, double hi) {
      final lower = ((max - r) * (lo + offset) + r).round();
      final upper = ((max - r) * (hi + offset) + r).round();
      return (lower, math.max(lower + 1, upper));
    }
    return {
      1: pp(0.50, 0.60),
      2: pp(0.60, 0.70),
      3: pp(0.70, 0.80),
      4: pp(0.80, 0.90),
      5: pp(0.90, 1.00),
    };
  }
}
