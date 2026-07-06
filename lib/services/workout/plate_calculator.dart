/// Works out which plates to load on a barbell to hit a target weight.
///
/// All maths is in kilograms. The result is per-side (a barbell is loaded
/// symmetrically), plus whatever couldn't be matched exactly so the UI can
/// warn "closest you can load is X".
class PlateCalculator {
  /// Standard metric plate denominations, heaviest first. Fractional
  /// plates (1.25, 0.5) are included so olympic micro-loading works.
  static const List<double> metricPlates = [
    25,
    20,
    15,
    10,
    5,
    2.5,
    1.25,
    0.5,
  ];

  /// Common bar weights the user can pick between.
  static const double olympicBar = 20;
  static const double womensBar = 15;
  static const double ezBar = 7.5;

  /// Greedy plate breakdown for [targetKg] on a bar of [barKg], choosing
  /// from [plates] (defaults to [metricPlates]). Returns the plates for
  /// ONE side and the exact loaded total (which may be a hair under the
  /// target when it isn't divisible by the available plates).
  static PlateSolution solve({
    required double targetKg,
    double barKg = olympicBar,
    List<double>? plates,
  }) {
    final avail = plates ?? metricPlates;
    if (targetKg <= barKg) {
      return PlateSolution(
        perSide: const [],
        loadedTotalKg: barKg,
        barKg: barKg,
        targetKg: targetKg,
      );
    }
    var perSide = (targetKg - barKg) / 2;
    final result = <double>[];
    for (final p in avail) {
      while (perSide >= p - 1e-9) {
        result.add(p);
        perSide -= p;
      }
    }
    final loadedPerSide =
        result.fold<double>(0, (s, p) => s + p);
    return PlateSolution(
      perSide: result,
      loadedTotalKg: barKg + loadedPerSide * 2,
      barKg: barKg,
      targetKg: targetKg,
    );
  }
}

class PlateSolution {
  /// Plates for one side of the bar, heaviest first.
  final List<double> perSide;

  /// The total weight actually achievable with these plates + bar.
  final double loadedTotalKg;
  final double barKg;
  final double targetKg;

  const PlateSolution({
    required this.perSide,
    required this.loadedTotalKg,
    required this.barKg,
    required this.targetKg,
  });

  /// True when the plates hit the target exactly (within rounding).
  bool get isExact => (loadedTotalKg - targetKg).abs() < 0.01;

  /// Collapsed "2×20, 1×5" style counts, heaviest first.
  List<PlateCount> get grouped {
    final counts = <double, int>{};
    for (final p in perSide) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries
        .map((e) => PlateCount(weightKg: e.key, count: e.value))
        .toList();
  }
}

class PlateCount {
  final double weightKg;
  final int count;
  const PlateCount({required this.weightKg, required this.count});
}
