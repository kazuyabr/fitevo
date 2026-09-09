import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/enums.dart';
import '../../services/workout/pr_tracker.dart';
import '../../services/workout/strength_standards.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/skeleton.dart';
import '../../l10n/app_localizations.dart';

class PrPage extends ConsumerWidget {
  const PrPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final sessionsAsync = ref.watch(allSessionsProvider);
    final profile = ref.watch(profileStreamProvider).valueOrNull;
    final bodyweight = profile?.weightKg ?? 0;
    final gender = profile?.gender ?? Gender.male;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.personalRecords, style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        // Skeleton rows shaped like the PR list while sessions load.
        child: sessionsAsync.when(
          loading: () => ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, _) => const SkeletonRow(height: 64),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (sessions) {
            final prs = PrTracker.personalRecords(sessions);
            if (prs.isEmpty) return const _Empty();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: prs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _PrRow(
                pr: prs[i],
                bodyweightKg: bodyweight,
                gender: gender,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.emoji_events_rounded,
                  size: 28, color: AppColors.accent),
            ),
            const SizedBox(height: 18),
            Text(AppLocalizations.of(context)!.noRecordsYet,
                style: AppText.sectionTitle.copyWith(fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              'Log a workout — your best estimated 1-rep max for each exercise lands here.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrRow extends StatelessWidget {
  final PrEntry pr;
  final double bodyweightKg;
  final Gender gender;
  const _PrRow({
    required this.pr,
    required this.bodyweightKg,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    final w = pr.weightKg;
    final wStr =
        w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
    final e = pr.estimated1RM;
    final eStr =
        e == e.roundToDouble() ? e.toInt().toString() : e.toStringAsFixed(1);
    // Strength tier for benchmarked compound lifts (bench/squat/deadlift/
    // OHP/row). Null for accessories or when bodyweight is unknown.
    final assessment = StrengthStandards.assess(
      exerciseName: pr.exerciseName,
      estimated1RM: pr.estimated1RM,
      bodyweightKg: bodyweightKg,
      gender: gender,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.emoji_events_rounded,
                size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pr.exerciseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  pr.weightKg > 0
                      ? '$wStr kg × ${pr.reps} · ${DateFormat('MMM d').format(pr.achievedAt)}'
                      : '${pr.reps} reps · ${DateFormat('MMM d').format(pr.achievedAt)}',
                  style: AppText.meta.copyWith(fontSize: 12),
                ),
                if (assessment != null) ...[
                  const SizedBox(height: 6),
                  _StrengthBadge(assessment: assessment),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$eStr kg',
                  style: AppText.bigNumber.copyWith(fontSize: 16)),
              Text(AppLocalizations.of(context)!.est1rm,
                  style: AppText.meta.copyWith(
                      fontSize: 10, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pill showing the strength tier for a benchmarked lift plus its
/// bodyweight ratio, e.g. "Intermediate · 1.4× BW". Colour ramps from
/// muted (untrained) to accent (elite).
class _StrengthBadge extends StatelessWidget {
  final StrengthAssessment assessment;
  const _StrengthBadge({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final tint = switch (assessment.level) {
      StrengthLevel.untrained => AppColors.textTertiary,
      StrengthLevel.novice => AppColors.water,
      StrengthLevel.intermediate => AppColors.water,
      StrengthLevel.advanced => AppColors.accent,
      StrengthLevel.elite => AppColors.accent,
    };
    final ratio = assessment.bodyweightRatio;
    final ratioStr = ratio.toStringAsFixed(ratio >= 10 ? 0 : 2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${StrengthStandards.label(assessment.level)} · $ratioStr× BW',
        style: TextStyle(
          color: tint == AppColors.textTertiary
              ? AppColors.textSecondary
              : tint,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
