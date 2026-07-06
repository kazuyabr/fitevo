import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_selector/muscle_selector.dart';

import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../services/workout/muscle_volume.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/skeleton.dart';

// Measured bounds of the package's front+back body SVG (its paths use
// relative commands and start at a non-zero origin, so the map draws the
// body offset by (minX, minY) inside its box — we undo that to centre it).
const double _kMapW = 313.1;
const double _kMapH = 260.1;
const double _kMinX = 15.1;
const double _kMinY = 13.5;
const double _kBodyAspect = _kMapW / _kMapH; // ≈ 1.204

/// Renders the muscle body at full available width. Height is derived from
/// the true SVG aspect, and a Transform undoes the SVG's origin offset so
/// the figure is centred and fully visible (no clipped legs, no left gap).
Widget _fittedBody({
  required List<String> selectedGroups,
  Key? key,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = w / _kBodyAspect;
      final scale = w / _kMapW;
      return SizedBox(
        width: w,
        height: h,
        child: ClipRect(
          child: Transform.translate(
            offset: Offset(-_kMinX * scale, -_kMinY * scale),
            child: MusclePickerMap(
              key: key,
              map: Maps.BODY,
              width: w,
              height: h,
              isEditing: true,
              actAsToggle: false,
              initialSelectedGroups: selectedGroups,
              onChanged: (_) {},
              dotColor: Colors.transparent,
              selectedColor: AppColors.accent,
              strokeColor: AppColors.textTertiary,
            ),
          ),
        ),
      );
    },
  );
}

/// Maps our [MuscleGroup] enum onto the muscle_selector package's SVG
/// group ids (note its spelling: "harmstrings", "forearm").
const Map<MuscleGroup, List<String>> _pkgGroups = {
  MuscleGroup.chest: ['chest'],
  MuscleGroup.back: ['lats', 'upper_back', 'lower_back'],
  MuscleGroup.shoulders: ['shoulders'],
  MuscleGroup.biceps: ['biceps'],
  MuscleGroup.triceps: ['triceps'],
  MuscleGroup.forearms: ['forearm'],
  MuscleGroup.quads: ['quads'],
  MuscleGroup.hamstrings: ['harmstrings'],
  MuscleGroup.glutes: ['glutes'],
  MuscleGroup.calves: ['calves'],
  MuscleGroup.core: ['abs', 'obliques'],
};

/// Bottom sheet showing the anatomical body with a single exercise's
/// muscles highlighted — opened from the workout overlay so the user can
/// see exactly what they're training.
class ExerciseMuscleSheet {
  static Future<void> show(
    BuildContext context, {
    required String exerciseName,
    required List<MuscleGroup> muscles,
  }) {
    final groups = <String>{};
    for (final m in muscles) {
      groups.addAll(_pkgGroups[m] ?? const []);
    }
    final named = muscles
        .where((m) => m != MuscleGroup.cardio && m != MuscleGroup.fullBody)
        .toList();
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('MUSCLES WORKED', style: AppText.label),
              const SizedBox(height: 2),
              Text(exerciseName,
                  style: AppText.sectionTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No muscle map for this exercise.',
                        style: AppText.body),
                  ),
                )
              else
                Center(
                  child: SizedBox(
                    width: 240,
                    child: _fittedBody(selectedGroups: groups.toList()),
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in named)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        MuscleVolumeService.muscleLabel(m),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Weekly muscle heatmap — a front + back body coloured by how much each
/// muscle was trained in the last 7 days, plus a per-muscle readout of
/// sets vs. MEV/MAV/MRV landmarks (undertrained → too much).
class MuscleMapPage extends ConsumerWidget {
  const MuscleMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsProvider);
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('Muscle map', style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const _MapSkeleton(),
          error: (_, _) => const SizedBox.shrink(),
          data: (sessions) {
            final exercises = exercisesAsync.valueOrNull ?? const <Exercise>[];
            final byId = {for (final e in exercises) e.id: e};
            final now = DateTime.now();
            final setsByMuscle = MuscleVolumeService.weeklySetsByMuscle(
              sessions,
              byId,
              now: now,
            );
            final readout = MuscleVolumeService.readout(
              sessions,
              byId,
              now: now,
            );
            final trainedThisWeek =
                setsByMuscle.values.fold<int>(0, (a, b) => a + b);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text('LAST 7 DAYS', style: AppText.label),
                const SizedBox(height: 12),
                // Real anatomical body — trained muscles highlighted.
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Column(
                    children: [
                      // Always show the body — un-highlighted when nothing
                      // was trained in the last 7 days.
                      _fittedBody(
                        selectedGroups: _trainedGroups(setsByMuscle),
                        key: ValueKey(
                            'full_${_trainedGroups(setsByMuscle).join(',')}'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Trained in the last 7 days',
                              style: AppText.meta.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (trainedThisWeek > 0) ...[
                  const SizedBox(height: 22),
                  Text('BALANCE', style: AppText.label),
                  const SizedBox(height: 12),
                  _BalanceCard(
                      report: MuscleVolumeService.balance(setsByMuscle)),
                ],
                const SizedBox(height: 22),
                Text('WEEKLY VOLUME', style: AppText.label),
                const SizedBox(height: 4),
                Text(
                  'Sets per muscle vs. optimal range.',
                  style: AppText.meta.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 12),
                for (final mv in readout) ...[
                  _MuscleRow(mv: mv),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

}

/// Package group ids for every muscle trained at least once this week.
List<String> _trainedGroups(Map<MuscleGroup, int> setsByMuscle) {
  final out = <String>{};
  setsByMuscle.forEach((muscle, sets) {
    if (sets <= 0) return;
    out.addAll(_pkgGroups[muscle] ?? const []);
  });
  return out.toList()..sort();
}

/// Compact tappable muscle-map card for the workout tab — a small real
/// body with this week's trained muscles highlighted. Tapping opens the
/// full [MuscleMapPage] (body + balance + weekly volume).
class MuscleMapPreviewCard extends ConsumerWidget {
  const MuscleMapPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(allSessionsProvider).valueOrNull ?? const [];
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? const [];
    // Always shown — with an un-highlighted body when nothing's trained
    // today, so the card is discoverable.
    final byId = {for (final e in exercises) e.id: e};
    // Front screen shows TODAY only — resets at midnight.
    final setsByMuscle = MuscleVolumeService.todaySetsByMuscle(
      sessions,
      byId,
      now: DateTime.now(),
    );
    final trained = _trainedGroups(setsByMuscle);
    final totalSets = setsByMuscle.values.fold<int>(0, (a, b) => a + b);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MuscleMapPage())),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.accessibility_new_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('MUSCLE MAP', style: AppText.label),
                const Spacer(),
                if (totalSets > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$totalSets sets · today',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textTertiary),
              ],
            ),
            const SizedBox(height: 8),
            // Always show the body — un-highlighted when nothing's trained
            // today. Constrained to a smaller width, centred, so the whole
            // body shows in a compact card (height scales with it).
            IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 210,
                  child: _fittedBody(
                    selectedGroups: trained,
                    key: ValueKey('preview_${trained.join(',')}'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('Tap for full map · balance · weekly volume',
                  style: AppText.meta.copyWith(
                      fontSize: 11, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

Color _zoneColor(VolumeZone z) => switch (z) {
      VolumeZone.none => AppColors.textTertiary,
      VolumeZone.under => AppColors.water,
      VolumeZone.optimal => const Color(0xFF2FB673),
      VolumeZone.high => AppColors.accent,
      VolumeZone.tooMuch => AppColors.danger,
    };

class _MuscleRow extends StatelessWidget {
  final MuscleVolume mv;
  const _MuscleRow({required this.mv});

  @override
  Widget build(BuildContext context) {
    final tint = _zoneColor(mv.zone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              MuscleVolumeService.muscleLabel(mv.muscle),
              style: AppText.body.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${mv.weeklySets} set${mv.weeklySets == 1 ? '' : 's'}',
            style: AppText.meta.copyWith(fontSize: 12),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tint.withValues(alpha: 0.4)),
            ),
            child: Text(
              MuscleVolumeService.zoneLabel(mv.zone),
              style: TextStyle(
                color: tint == AppColors.textTertiary
                    ? AppColors.textSecondary
                    : tint,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final BalanceReport report;
  const _BalanceCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final warning = report.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: [
          _bar('Push', report.push, 'Pull', report.pull),
          const SizedBox(height: 14),
          _bar('Quads', report.quads, 'Hamstrings', report.hamstrings),
          if (warning != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.water),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: AppText.meta.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(String aName, int a, String bName, int b) {
    final total = (a + b) == 0 ? 1 : (a + b);
    final aFrac = a / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$aName · $a',
                style: AppText.meta.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text('$b · $bName',
                style: AppText.meta.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Expanded(
                flex: (aFrac * 1000).round().clamp(1, 999),
                child: Container(height: 8, color: AppColors.accent),
              ),
              Expanded(
                flex: ((1 - aFrac) * 1000).round().clamp(1, 999),
                child: Container(height: 8, color: AppColors.water),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapSkeleton extends StatelessWidget {
  const _MapSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const SkeletonBox(
            height: 300,
            borderRadius: BorderRadius.all(Radius.circular(22))),
        const SizedBox(height: 22),
        for (int i = 0; i < 6; i++) ...[
          const SkeletonRow(height: 48),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
