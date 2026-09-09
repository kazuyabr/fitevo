import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../data/models/workout_session.dart';
import '../../l10n/app_localizations.dart';

/// Where a muscle's weekly set count sits against evidence-based landmarks.
///   • under      — below the minimum effective volume (undertrained)
///   • optimal    — in the productive MEV→MAV range
///   • high       — above MAV but under the max recoverable volume
///   • tooMuch    — beyond MRV; likely junk volume / recovery risk
///   • none       — zero sets this week
enum VolumeZone { none, under, optimal, high, tooMuch }

class MuscleVolume {
  final MuscleGroup muscle;
  final int weeklySets;
  final VolumeZone zone;
  const MuscleVolume({
    required this.muscle,
    required this.weeklySets,
    required this.zone,
  });
}

class BalanceReport {
  final int push;
  final int pull;
  final int quads;
  final int hamstrings;
  const BalanceReport({
    required this.push,
    required this.pull,
    required this.quads,
    required this.hamstrings,
  });

  /// A short warning if either pair is meaningfully lopsided, else null.
  String? get warning {
    final w1 = _lopsided('push', push, 'pull', pull);
    if (w1 != null) return w1;
    return _lopsided('quads', quads, 'hamstrings', hamstrings);
  }

  static String? _lopsided(String aName, int a, String bName, int b) {
    // Need enough total volume for the ratio to mean anything.
    if (a + b < 6) return null;
    final hi = a >= b ? a : b;
    final lo = a >= b ? b : a;
    final hiName = a >= b ? aName : bName;
    final loName = a >= b ? bName : aName;
    if (lo == 0 || hi / lo >= 1.6) {
      return 'You train $hiName ${lo == 0 ? 'but skip' : 'far more than'} '
          '$loName — add $loName volume to stay balanced.';
    }
    return null;
  }
}

/// Computes weekly training volume per muscle from logged sessions and
/// classifies it against MEV / MAV / MRV landmarks (generalized from
/// Renaissance Periodization). Powers the muscle heatmap and the
/// "undertrained / optimal / too much" readout.
class MuscleVolumeService {
  /// Weekly set landmarks per muscle: (MEV, MAV, MRV). Smaller muscles
  /// tolerate and need more sets; big compound-driven muscles fewer.
  static const Map<MuscleGroup, (int, int, int)> _landmarks = {
    MuscleGroup.chest: (8, 16, 22),
    MuscleGroup.back: (10, 18, 25),
    MuscleGroup.shoulders: (8, 18, 26),
    MuscleGroup.biceps: (6, 14, 20),
    MuscleGroup.triceps: (6, 14, 20),
    MuscleGroup.forearms: (4, 10, 16),
    MuscleGroup.quads: (8, 16, 22),
    MuscleGroup.hamstrings: (6, 14, 20),
    MuscleGroup.glutes: (6, 14, 20),
    MuscleGroup.calves: (8, 16, 22),
    MuscleGroup.core: (6, 16, 25),
  };

  static const (int, int, int) _defaultLandmark = (8, 16, 22);

  /// Core: count working sets per muscle across the given sessions.
  static Map<MuscleGroup, int> _count(
    Iterable<WorkoutSession> sessions,
    Map<int, Exercise> exercisesById,
  ) {
    final counts = <MuscleGroup, int>{};
    for (final s in sessions) {
      for (final set in s.sets) {
        if (set.setType == SetType.warmup) continue;
        final ex = exercisesById[set.exerciseId];
        final muscles = ex?.muscleGroups ?? const <MuscleGroup>[];
        for (final m in muscles) {
          if (m == MuscleGroup.cardio || m == MuscleGroup.fullBody) continue;
          counts[m] = (counts[m] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// Sets logged per muscle over the [days] days ending at [now]. Warmup
  /// sets are excluded. Each working set counts once toward every muscle
  /// the exercise targets.
  static Map<MuscleGroup, int> weeklySetsByMuscle(
    List<WorkoutSession> sessions,
    Map<int, Exercise> exercisesById, {
    required DateTime now,
    int days = 7,
  }) {
    final cutoff = now.subtract(Duration(days: days));
    return _count(
        sessions.where((s) => s.startedAt.isAfter(cutoff)), exercisesById);
  }

  /// Sets logged per muscle on the same calendar day as [now]. Resets at
  /// midnight — powers the "today's trained muscles" front-screen preview.
  static Map<MuscleGroup, int> todaySetsByMuscle(
    List<WorkoutSession> sessions,
    Map<int, Exercise> exercisesById, {
    required DateTime now,
  }) {
    final key = WorkoutSession.keyFor(now);
    return _count(
      sessions.where((s) => WorkoutSession.keyFor(s.startedAt) == key),
      exercisesById,
    );
  }

  /// Classifies a muscle's weekly set count against its landmarks.
  static VolumeZone zoneFor(MuscleGroup muscle, int sets) {
    if (sets <= 0) return VolumeZone.none;
    final (mev, mav, mrv) = _landmarks[muscle] ?? _defaultLandmark;
    if (sets < mev) return VolumeZone.under;
    if (sets <= mav) return VolumeZone.optimal;
    if (sets <= mrv) return VolumeZone.high;
    return VolumeZone.tooMuch;
  }

  /// Full per-muscle readout (every trackable muscle, including zeroes)
  /// sorted most-trained first — for the heatmap + list.
  static List<MuscleVolume> readout(
    List<WorkoutSession> sessions,
    Map<int, Exercise> exercisesById, {
    required DateTime now,
  }) {
    final counts = weeklySetsByMuscle(sessions, exercisesById, now: now);
    final muscles = _landmarks.keys.toList();
    final list = [
      for (final m in muscles)
        MuscleVolume(
          muscle: m,
          weeklySets: counts[m] ?? 0,
          zone: zoneFor(m, counts[m] ?? 0),
        ),
    ];
    list.sort((a, b) => b.weeklySets.compareTo(a.weeklySets));
    return list;
  }

  /// 0..1 intensity for heatmap colouring — how hot a muscle is relative
  /// to its own MAV (the productive ceiling).
  static double intensity(MuscleGroup muscle, int sets) {
    if (sets <= 0) return 0;
    final (_, mav, _) = _landmarks[muscle] ?? _defaultLandmark;
    return (sets / mav).clamp(0.0, 1.0);
  }

  static String zoneLabel(VolumeZone z) => switch (z) {
        VolumeZone.none => 'Not trained',
        VolumeZone.under => 'Undertrained',
        VolumeZone.optimal => 'Optimal',
        VolumeZone.high => 'High',
        VolumeZone.tooMuch => 'Too much',
      };

  /// Push vs pull and quad vs hamstring balance from weekly sets. Big
  /// imbalances (>~1.6×) predict posture/shoulder and knee/hamstring
  /// injury risk, so they're worth surfacing.
  static BalanceReport balance(Map<MuscleGroup, int> sets) {
    int g(MuscleGroup m) => sets[m] ?? 0;
    final push =
        g(MuscleGroup.chest) + g(MuscleGroup.shoulders) + g(MuscleGroup.triceps);
    final pull = g(MuscleGroup.back) + g(MuscleGroup.biceps);
    final quads = g(MuscleGroup.quads);
    final hams = g(MuscleGroup.hamstrings);
    return BalanceReport(
      push: push,
      pull: pull,
      quads: quads,
      hamstrings: hams,
    );
  }

  static String muscleLabel(MuscleGroup m) => switch (m) {
        MuscleGroup.chest => 'Chest',
        MuscleGroup.back => 'Back',
        MuscleGroup.shoulders => 'Shoulders',
        MuscleGroup.biceps => 'Biceps',
        MuscleGroup.triceps => 'Triceps',
        MuscleGroup.forearms => 'Forearms',
        MuscleGroup.quads => 'Quads',
        MuscleGroup.hamstrings => 'Hamstrings',
        MuscleGroup.glutes => 'Glutes',
        MuscleGroup.calves => 'Calves',
        MuscleGroup.core => 'Core',
        MuscleGroup.cardio => 'Cardio',
        MuscleGroup.fullBody => 'Full body',
      };
}
