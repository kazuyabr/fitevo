// ignore_for_file: use_null_aware_elements
// isar_generator's bundled analyzer can't parse `?value` yet, so we use
// the equivalent `if (value != null)` form instead.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/enums.dart';
import '../../data/models/profile.dart';
import '../../data/models/routine.dart';
import '../../data/models/workout_session.dart';
import '../../services/ai/ai_service.dart';
import '../../services/workout/progression_coach.dart';
import '../../services/workout/volume_calc.dart';
import 'cardio_log_sheet.dart';
import 'mobility_flow_page.dart';
import 'muscle_map_page.dart';
import 'soreness_sheet.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/skeleton.dart';
import 'pr_page.dart';
import 'routine_builder_page.dart';
import 'routine_day_detail_page.dart';
import 'template_picker_sheet.dart';
import 'workout_logger_page.dart';
import 'workout_photos.dart';

class WorkoutPage extends ConsumerWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineAsync = ref.watch(activeRoutineProvider);
    final profileAsync = ref.watch(profileStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: profileAsync.when(
        loading: () => _busy(),
        error: (_, _) => _busy(),
        data: (profile) {
          if (profile == null) return _busy();
          return routineAsync.when(
            loading: () => _busy(),
            error: (_, _) => _busy(),
            data: (routine) => routine == null
                ? _EmptyState(profile: profile)
                : _RoutineView(routine: routine, profile: profile),
          );
        },
      ),
    );
  }

  // Skeleton mirroring the routine view: title, week-day strip, hero
  // day card, then a couple of day rows.
  Widget _busy() => SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 160, height: 22),
              const SizedBox(height: 6),
              const SkeletonBox(width: 220, height: 12),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (int i = 0; i < 7; i++) ...[
                    const Expanded(
                        child: SkeletonBox(
                            height: 62,
                            borderRadius:
                                BorderRadius.all(Radius.circular(14)))),
                    if (i < 6) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              const SkeletonBox(
                  height: 200,
                  borderRadius: BorderRadius.all(Radius.circular(24))),
              const SizedBox(height: 14),
              const SkeletonRow(height: 64),
              const SizedBox(height: 10),
              const SkeletonRow(height: 64),
            ],
          ),
        ),
      );
}

// ===========================================================================
// EMPTY STATE — no routine yet
// ===========================================================================

class _EmptyState extends ConsumerStatefulWidget {
  final Profile profile;
  const _EmptyState({required this.profile});

  @override
  ConsumerState<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends ConsumerState<_EmptyState> {
  bool _busy = false;

  Future<void> _generate() async {
    // Ask sets + rep-range preferences first so the AI knows what to
    // build. User can pick numbers or say "AI decides" for either.
    final prefs = await showDialog<_TrainingPrefs>(
      context: context,
      builder: (_) => const _TrainingPrefsDialog(),
    );
    if (prefs == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(routineGeneratorProvider).generateAndActivate(
            goal: widget.profile.goal,
            trainingDaysPerWeek: widget.profile.trainingDaysPerWeek,
            restDays: widget.profile.restDays.toList(),
            workoutType: widget.profile.workoutType,
            preferredSets: prefs.sets,
            preferredRepsLow: prefs.repsLow,
            preferredRepsHigh: prefs.repsHigh,
          );
    } catch (e) {
      if (!mounted) return;
      _toast(e is AiException ? e.message : 'Could not generate routine.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData _typeIcon(WorkoutType t) => switch (t) {
        WorkoutType.gym => Icons.fitness_center_rounded,
        WorkoutType.homeWorkout => Icons.home_rounded,
        WorkoutType.yoga => Icons.self_improvement_rounded,
        WorkoutType.meditation => Icons.spa_rounded,
        WorkoutType.none => Icons.directions_walk_rounded,
      };

  String _typeLabel(WorkoutType t) => switch (t) {
        WorkoutType.gym => 'GYM WORKOUT',
        WorkoutType.homeWorkout => 'HOME WORKOUT',
        WorkoutType.yoga => 'YOGA PRACTICE',
        WorkoutType.meditation => 'MINDFULNESS',
        WorkoutType.none => 'WELLNESS',
      };

  String _typeHeadline(WorkoutType t) => switch (t) {
        WorkoutType.gym => 'BUILD\nYOUR\nROUTINE.',
        WorkoutType.homeWorkout => 'TRAIN\nFROM\nHOME.',
        WorkoutType.yoga => 'FLOW\nYOUR\nPRACTICE.',
        WorkoutType.meditation => 'CALM\nYOUR\nMIND.',
        WorkoutType.none => 'START\nYOUR\nJOURNEY.',
      };

  String _typeSubtitle(Profile p) => switch (p.workoutType) {
        WorkoutType.gym =>
          'AI builds a smart gym split based on your goal and ${p.trainingDaysPerWeek} training days a week.',
        WorkoutType.homeWorkout =>
          'No gym needed. Bodyweight & dumbbell sessions built for ${p.trainingDaysPerWeek} training days a week.',
        WorkoutType.yoga =>
          'AI crafts a ${p.trainingDaysPerWeek}-day yoga plan aligned with your fitness goal and experience.',
        WorkoutType.meditation =>
          'Structured breathwork and mindfulness sessions for a daily mental wellness practice.',
        WorkoutType.none =>
          'A gentle wellness plan to get you moving every day — no experience needed.',
      };

  List<(IconData, String)> _typePills(Profile p) => switch (p.workoutType) {
        WorkoutType.gym => [
            (Icons.auto_awesome_rounded, 'AI POWERED'),
            (Icons.person_rounded, _goalLabel(p.goal)),
            (Icons.trending_up_rounded, 'PROGRESSIVE'),
          ],
        WorkoutType.homeWorkout => [
            (Icons.auto_awesome_rounded, 'AI POWERED'),
            (Icons.home_rounded, 'NO EQUIPMENT'),
            (Icons.trending_up_rounded, 'PROGRESSIVE'),
          ],
        WorkoutType.yoga => [
            (Icons.auto_awesome_rounded, 'AI POWERED'),
            (Icons.self_improvement_rounded, 'MIND + BODY'),
            (Icons.loop_rounded, 'DAILY FLOW'),
          ],
        WorkoutType.meditation => [
            (Icons.auto_awesome_rounded, 'AI POWERED'),
            (Icons.air_rounded, 'BREATHWORK'),
            (Icons.favorite_rounded, 'DAILY PEACE'),
          ],
        WorkoutType.none => [
            (Icons.auto_awesome_rounded, 'AI POWERED'),
            (Icons.directions_walk_rounded, 'GENTLE START'),
            (Icons.trending_up_rounded, 'FLEXIBLE'),
          ],
      };

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content:
            Text(msg, style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return _WorkoutTypeBg(
      type: widget.profile.workoutType,
      child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 52),
                // Type identity mark
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_typeIcon(widget.profile.workoutType),
                          size: 16, color: AppColors.onAccent),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _typeLabel(widget.profile.workoutType),
                      style: AppText.label.copyWith(
                        color: AppColors.accent,
                        letterSpacing: 2,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 60.ms, duration: 280.ms),

                const SizedBox(height: 32),

                // Big hero headline (type-specific)
                Text(
                  _typeHeadline(widget.profile.workoutType),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -2.0,
                    height: 0.95,
                  ),
                ).animate().fadeIn(delay: 120.ms, duration: 300.ms).slideY(begin: 0.08, end: 0),

                const SizedBox(height: 16),

                Text(
                  _typeSubtitle(widget.profile),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 180.ms, duration: 280.ms),

                const SizedBox(height: 28),

                // Feature pills (type-specific)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _typePills(widget.profile))
                      _FeaturePill(p.$1, p.$2),
                  ],
                ).animate().fadeIn(delay: 220.ms, duration: 280.ms),

                const Spacer(),

                // Generate button
                GestureDetector(
                  onTap: _busy ? null : _generate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 62,
                    decoration: BoxDecoration(
                      color: _busy
                          ? AppColors.accent.withValues(alpha: 0.5)
                          : AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: _busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.onAccent))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: AppColors.onAccent, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                'GENERATE MY ROUTINE',
                                style: TextStyle(
                                  color: AppColors.onAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                  ),
                ).animate().fadeIn(delay: 280.ms, duration: 280.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 12),

                // Build-your-own ghost button
                GestureDetector(
                  onTap: _busy
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const RoutineBuilderPage())),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 8),
                        Text(
                          'Build your own',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 320.ms, duration: 280.ms),

                const SizedBox(height: 12),

                // Ready-made template ghost button
                GestureDetector(
                  onTap: _busy
                      ? null
                      : () => TemplatePickerSheet.show(context),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 8),
                        Text(
                          'Use a template',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 360.ms, duration: 280.ms),
              ],
            ),
          ),
        ),
    );
  }

  String _goalLabel(FitnessGoal g) {
    switch (g) {
      case FitnessGoal.buildMuscle:
        return 'BUILD MUSCLE';
      case FitnessGoal.loseFat:
        return 'LOSE FAT';
      case FitnessGoal.recomp:
        return 'RECOMP';
      case FitnessGoal.generalFitness:
        return 'FITNESS';
    }
  }
}

// ===========================================================================
// TYPE BACKGROUND — Unsplash photo base + Pexels looping video on top when
// the platform supports it (mobile). Photo alone still looks premium on
// Windows / older devices where the video engine can't initialise.
// ===========================================================================

class _WorkoutTypeBg extends StatefulWidget {
  final WorkoutType type;
  final Widget child;
  const _WorkoutTypeBg({required this.type, required this.child});

  @override
  State<_WorkoutTypeBg> createState() => _WorkoutTypeBgState();
}

class _WorkoutTypeBgState extends State<_WorkoutTypeBg> {
  // Video layer removed — user asked for photos-only with Ken Burns
  // zoom (which they hand-picked). Photos cycle below.

  // Multiple photos per type → the background slowly crossfades between
  // them with a Ken-Burns slow-zoom on each so motion never stops.
  static const _photoUrls = <WorkoutType, List<String>>{
    WorkoutType.gym: [
      'https://plus.unsplash.com/premium_photo-1664109999537-088e7d964da2?w=1600&q=80&fit=crop',
      'https://images.unsplash.com/photo-1646072508263-af94f0218bf0?w=1600&q=80&fit=crop',
      'https://plus.unsplash.com/premium_photo-1664109999476-58db99e8b785?w=1600&q=80&fit=crop',
      'https://plus.unsplash.com/premium_photo-1661609478485-340c97cc2b5d?w=1600&q=80&fit=crop',
      'https://plus.unsplash.com/premium_photo-1674059549221-e2943b475f62?w=1600&q=80&fit=crop',
      'https://images.unsplash.com/photo-1601986313624-28c11ac26334?w=1600&q=80&fit=crop',
    ],
    WorkoutType.homeWorkout: [
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1600&q=75&fit=crop',
    ],
    WorkoutType.yoga: [
      'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=1600&q=75&fit=crop',
    ],
    WorkoutType.meditation: [
      'https://images.unsplash.com/photo-1512438248247-f0f2a5a8b7f0?w=1600&q=75&fit=crop',
    ],
    WorkoutType.none: [
      'https://plus.unsplash.com/premium_photo-1664109999537-088e7d964da2?w=1600&q=80&fit=crop',
    ],
  };

  static const _cycleInterval = Duration(milliseconds: 2500);
  static const _crossfadeDuration = Duration(milliseconds: 1400);
  int _photoIndex = 0;
  Timer? _photoTimer;

  static Color _baseColor(WorkoutType t) => switch (t) {
        WorkoutType.gym => const Color(0xFF1A0800),
        WorkoutType.homeWorkout => const Color(0xFF001A14),
        WorkoutType.yoga => const Color(0xFF16001A),
        WorkoutType.meditation => const Color(0xFF00101A),
        WorkoutType.none => const Color(0xFF0D0D0D),
      };

  @override
  void initState() {
    super.initState();
    _startPhotoCycle();
  }

  void _startPhotoCycle() {
    final list = _photoUrls[widget.type] ?? const <String>[];
    if (list.length < 2) return;
    _photoTimer = Timer.periodic(_cycleInterval, (_) {
      if (!mounted) return;
      setState(() => _photoIndex = (_photoIndex + 1) % list.length);
    });
  }

  @override
  void dispose() {
    _photoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _photoUrls[widget.type] ?? _photoUrls[WorkoutType.gym]!;
    final photoUrl = list[_photoIndex % list.length];
    final isLight = AppColors.current.brightness == Brightness.light;

    // Vignette: dark top (headline area) + softer middle (photo shows) +
    // dark bottom (buttons area). White text always readable, photo still
    // reads as the hero. In light mode we push the wash a bit stronger
    // so the light system UI doesn't blend into the photo edges.
    final topAlpha = isLight ? 0xB0 : 0x99;
    final midAlpha = isLight ? 0x77 : 0x55;
    final bottomAlpha = isLight ? 0xF0 : 0xE6;
    final overlay = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color((topAlpha << 24) | 0x000000),
        Color((midAlpha << 24) | 0x000000),
        Color((bottomAlpha << 24) | 0x000000),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Solid base — no flash of white while photo loads
        Container(color: _baseColor(widget.type)),
        // Photo layer — high-quality Unsplash still, always visible on top
        // of the solid base. On mobile the video will cover it.
        // Full-screen photo layer: crossfade between URLs + Ken-Burns
        // slow-zoom on the active one so motion never stops.
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: _crossfadeDuration,
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: _KenBurnsBackground(
              key: ValueKey(photoUrl),
              url: photoUrl,
            ),
          ),
        ),
        // Mode-adaptive overlay for text legibility
        Container(decoration: BoxDecoration(gradient: overlay)),
        widget.child,
      ],
    );
  }
}

/// A single background photo with a slow Ken-Burns zoom. Self-contained
/// so `AnimatedSwitcher` can crossfade between instances of it — each
/// key change mounts a fresh copy that starts its zoom from scratch.
class _KenBurnsBackground extends StatefulWidget {
  final String url;
  const _KenBurnsBackground({super.key, required this.url});

  @override
  State<_KenBurnsBackground> createState() => _KenBurnsBackgroundState();
}

class _KenBurnsBackgroundState extends State<_KenBurnsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoomCtrl;

  @override
  void initState() {
    super.initState();
    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..forward();
  }

  @override
  void dispose() {
    _zoomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _zoomCtrl,
      builder: (context, child) {
        final scale = 1.0 + (Curves.easeInOut.transform(_zoomCtrl.value) * 0.12);
        return Transform.scale(scale: scale, child: child);
      },
      child: SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: widget.url,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          fadeInDuration: Duration.zero,
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        // Solid dark pill so it always reads over the photo/video
        // background, with an accent-tinted border for brand identity.
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// ROUTINE VIEW — has an active routine
// ===========================================================================

class _RoutineView extends ConsumerWidget {
  final Routine routine;
  final Profile profile;
  const _RoutineView({required this.routine, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todaysRoutineDayProvider);
    final sessionsAsync = ref.watch(recentSessionsProvider);
    final allSessionsAsync = ref.watch(allSessionsProvider);
    final sessions = sessionsAsync.valueOrNull ?? const [];

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ── Sporty header ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SportyHeader(
            routine: routine,
            workoutType: profile.workoutType,
            onRegenerate: () => _confirmReplace(context, ref),
            onEdit: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RoutineBuilderPage(edit: routine))),
            onDelete: () => _confirmDelete(context, ref, routine),
          ),
        ),

        // ── TODAY card ─────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverToBoxAdapter(
            child: todayAsync.when(
              loading: () => const SizedBox(height: 200),
              error: (_, _) => const SizedBox.shrink(),
              data: (day) => _TodayCard(routine: routine, day: day),
            ),
          ),
        ),

        // ── Coach insight: deload / plateau ────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _ProgressionInsightCard(
              allSessions: allSessionsAsync.valueOrNull ?? const [],
              routine: routine,
            ),
          ),
        ),

        // ── Muscle map preview (tap → full map + weekly volume) ────────
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: MuscleMapPreviewCard(),
          ),
        ),

        // ── Cardio ─────────────────────────────────────────────────────
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: CardioTodayCard(),
          ),
        ),

        // ── Recovery (soreness check-in + smart warning) ───────────────
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: RecoveryCard(),
          ),
        ),

        // ── THIS WEEK label + actions ──────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(child: Text('THIS WEEK', style: AppText.label)),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MobilityFlowPage())),
                  child: Row(
                    children: [
                      Icon(Icons.self_improvement_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('Mobility',
                          style: AppText.label.copyWith(
                              color: AppColors.accent, letterSpacing: 0.6)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrPage())),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('PRs',
                          style: AppText.label.copyWith(
                              color: AppColors.accent, letterSpacing: 0.6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Day rows ──────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList.builder(
            itemCount: routine.days.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DayRow(
                day: routine.days[i],
                routineName: routine.name,
              ),
            ),
          ),
        ),

        // ── Recent sessions ───────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Text('RECENT SESSIONS', style: AppText.label),
          ),
        ),

        if (sessions.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    Icon(Icons.fitness_center_rounded,
                        size: 20, color: AppColors.textTertiary),
                    const SizedBox(width: 12),
                    Text('No workouts logged yet — start today!',
                        style: AppText.body.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.builder(
              itemCount: sessions.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SessionRow(
                  session: sessions[i],
                  bodyWeightKg: profile.weightKg,
                  onDelete: () => _confirmDeleteSession(
                      context, ref, sessions[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmReplace(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Replace this routine?',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 8),
              Text('AI will draft a new split. Your past sessions are kept.',
                  style: AppText.body),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel',
                        style:
                            AppText.body.copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Regenerate',
                        style: AppText.body.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(workoutRepoProvider).deleteRoutine(routine.id);
      await ref.read(routineGeneratorProvider).generateAndActivate(
            goal: profile.goal,
            trainingDaysPerWeek: profile.trainingDaysPerWeek,
            restDays: profile.restDays.toList(),
            workoutType: profile.workoutType,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
            e is AiException ? e.message : 'Could not regenerate routine.',
            style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Routine routine) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete this routine?',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                  'All days in "${routine.name}" will be removed. Past sessions are kept.',
                  style: AppText.body),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel',
                        style:
                            AppText.body.copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Delete',
                        style: AppText.body.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(workoutRepoProvider).deleteRoutine(routine.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text('Could not delete routine.',
            style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
    }
  }

  Future<void> _confirmDeleteSession(
      BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final when = DateFormat('MMM d · h:mm a').format(session.startedAt);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete this session?',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                'Started $when · ${session.routineDayName}. '
                'This can\'t be undone.',
                style: AppText.body,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel',
                        style: AppText.body
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Delete',
                        style: AppText.body.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(workoutRepoProvider).deleteSession(session.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text('Could not delete session.',
            style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
    }
  }
}

// ── Sporty page header ────────────────────────────────────────────────────

class _SportyHeader extends StatelessWidget {
  final Routine routine;
  final WorkoutType workoutType;
  final VoidCallback onRegenerate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SportyHeader({
    required this.routine,
    required this.workoutType,
    required this.onRegenerate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);
    final dateName = DateFormat('MMM d').format(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayName, $dateName'.toUpperCase(),
                  style: AppText.label.copyWith(
                      fontSize: 10, color: AppColors.textTertiary, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  routine.name,
                  style: AppText.sectionTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(workoutType), size: 11, color: AppColors.accent),
                      const SizedBox(width: 5),
                      Text(
                        _typeLabel(workoutType),
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Overflow menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.stroke),
            ),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'regen') onRegenerate();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: _menuItem(Icons.edit_rounded, 'Edit routine', AppColors.textPrimary),
              ),
              PopupMenuItem(
                value: 'regen',
                child: _menuItem(Icons.auto_awesome_rounded, 'Regenerate with AI', AppColors.accent),
              ),
              PopupMenuItem(
                value: 'delete',
                child: _menuItem(Icons.delete_outline_rounded, 'Delete routine', AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, Color color) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: AppText.body
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      );

  IconData _typeIcon(WorkoutType t) => switch (t) {
        WorkoutType.gym => Icons.fitness_center_rounded,
        WorkoutType.homeWorkout => Icons.home_rounded,
        WorkoutType.yoga => Icons.self_improvement_rounded,
        WorkoutType.meditation => Icons.spa_rounded,
        WorkoutType.none => Icons.directions_walk_rounded,
      };

  String _typeLabel(WorkoutType t) => switch (t) {
        WorkoutType.gym => 'GYM WORKOUT',
        WorkoutType.homeWorkout => 'HOME WORKOUT',
        WorkoutType.yoga => 'YOGA PRACTICE',
        WorkoutType.meditation => 'MINDFULNESS',
        WorkoutType.none => 'WELLNESS',
      };
}

// ── Today card ────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final Routine routine;
  final RoutineDay? day;
  const _TodayCard({required this.routine, required this.day});

  @override
  Widget build(BuildContext context) {
    if (day == null || day!.isRest) return _RestDayCard();
    final d = day!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 230,
        child: WorkoutPhotoBackground(
          dayName: d.name,
          overlayStrength: 0.70,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: TODAY badge + time estimate
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'TODAY',
                        style: TextStyle(
                          color: AppColors.onAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_rounded,
                              size: 12, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            '~${_estimateMinutes(d)} MIN',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Day name
                Text(
                  d.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                // Exercise preview
                if (d.items.isNotEmpty)
                  Text(
                    d.items.take(3).map((e) => e.exerciseName).join(' · ') +
                        (d.items.length > 3 ? ' +${d.items.length - 3}' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 14),
                // Start button
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutLoggerPage(
                        routineName: routine.name,
                        day: d,
                      ),
                    ),
                  ),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'START WORKOUT',
                          style: TextStyle(
                            color: AppColors.onAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: AppColors.onAccent, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _estimateMinutes(RoutineDay d) {
    final sets = d.items.fold<int>(0, (s, i) => s + i.targetSets);
    return (sets * 4).clamp(20, 120);
  }
}

class _RestDayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.water.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.self_improvement_rounded,
                color: AppColors.water, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REST DAY',
                  style: AppText.label
                      .copyWith(color: AppColors.water, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('Recovery is where gains happen.',
                  style: AppText.sectionTitle.copyWith(fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Day row ───────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final RoutineDay day;
  final String routineName;
  const _DayRow({required this.day, required this.routineName});

  @override
  Widget build(BuildContext context) {
    final isRest = day.isRest;
    final accentColor = isRest ? AppColors.water : AppColors.accent;

    return GestureDetector(
      onTap: isRest
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoutineDayDetailPage(
                    day: day,
                    routineName: routineName,
                  ),
                ),
              ),
      behavior: HitTestBehavior.opaque,
      child: Container(
      height: 66,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 4,
            color: accentColor.withValues(alpha: 0.8),
          ),
          // Weekday chip
          SizedBox(
            width: 48,
            child: Center(
              child: Text(
                _weekdayLabel(day.weekday),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.stroke),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  isRest ? 'Rest & recover' : '${day.items.length} exercises',
                  style: AppText.meta.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isRest)
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 10),
        ],
      ),
      ),
    );
  }

  String _weekdayLabel(int w) {
    const names = ['—', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    if (w < 1 || w > 7) return '—';
    return names[w];
  }
}

// ── Weekly volume horizontal bar chart ───────────────────────────────────

/// Coach insight card — surfaces the single most important progression
/// signal: a deload recommendation (fatigue/pain) or a plateaued lift.
/// Renders nothing when training's on track, so it never nags.
class _ProgressionInsightCard extends StatelessWidget {
  final List<WorkoutSession> allSessions;
  final Routine routine;
  const _ProgressionInsightCard({
    required this.allSessions,
    required this.routine,
  });

  @override
  Widget build(BuildContext context) {
    if (allSessions.isEmpty) return const SizedBox.shrink();

    // Deload takes priority — it's a whole-program call.
    final deload = ProgressionCoach.deloadSignal(allSessions.take(10).toList());
    if (deload != null) {
      return _card(
        icon: Icons.battery_alert_rounded,
        tint: AppColors.danger,
        title: 'Time for a deload',
        body: deload.reason,
      );
    }

    // Otherwise, the first plateaued lift in the routine.
    final seen = <int>{};
    for (final day in routine.days) {
      for (final item in day.items) {
        if (!seen.add(item.exerciseId)) continue;
        final p = ProgressionCoach.plateau(allSessions, item.exerciseId);
        if (p != null) {
          return _card(
            icon: Icons.trending_flat_rounded,
            tint: AppColors.water,
            title: '${p.exerciseName} has stalled',
            body: 'No progress in ${p.stalledSessions} sessions. Try a '
                'variation for a few weeks, change the rep range, or add a set.',
          );
        }
      }
    }
    return const SizedBox.shrink();
  }

  Widget _card({
    required IconData icon,
    required Color tint,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final WorkoutSession session;
  final double bodyWeightKg;
  final VoidCallback onDelete;
  const _SessionRow({
    required this.session,
    required this.bodyWeightKg,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = session.completedAt != null;
    final durMin = session.duration.inMinutes;
    final kcal = VolumeCalc.sessionCalories(
      bodyWeightKg: bodyWeightKg,
      duration: session.duration,
    );
    final workSets = session.sets.where((s) => !s.isWarmup).length;

    return GestureDetector(
      onLongPress: onDelete,
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isComplete
              ? AppColors.protein.withValues(alpha: 0.25)
              : AppColors.stroke,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isComplete
                  ? AppColors.protein.withValues(alpha: 0.12)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isComplete ? Icons.check_rounded : Icons.timer_rounded,
              color: isComplete ? AppColors.protein : AppColors.textTertiary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.routineDayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d · h:mm a').format(session.startedAt),
                  style: AppText.meta.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$workSets sets',
                style: AppText.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                kcal > 0 ? '$durMin min · ~$kcal kcal' : '$durMin min',
                style: AppText.meta.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ─────────────────────── Training prefs dialog ───────────────────────

/// Selection returned by the pre-generate popup. Any field left null
/// means "let the AI decide" — the routine generator forwards that
/// intent to the AI prompt.
class _TrainingPrefs {
  final int? sets;
  final int? repsLow;
  final int? repsHigh;
  const _TrainingPrefs({this.sets, this.repsLow, this.repsHigh});
}

class _TrainingPrefsDialog extends StatefulWidget {
  const _TrainingPrefsDialog();

  @override
  State<_TrainingPrefsDialog> createState() => _TrainingPrefsDialogState();
}

enum _RepStyle { pyramid, straight }

class _TrainingPrefsDialogState extends State<_TrainingPrefsDialog> {
  // null = AI decides
  int? _sets;
  // Rep scheme: a descending pyramid (drop 2 per set from the top), the
  // same reps every set, or let the AI decide. Stored via targetRepsHigh
  // (first set) / targetRepsLow (last set) so no schema change is needed.
  _RepStyle _repStyle = _RepStyle.pyramid;
  int _topReps = 12;

  /// The exact reps for each set given the chosen [sets] count.
  List<int> _previewReps(int sets) {
    switch (_repStyle) {
      case _RepStyle.pyramid:
        return [for (int i = 0; i < sets; i++) (_topReps - 2 * i).clamp(1, 99)];
      case _RepStyle.straight:
        return List.filled(sets, _topReps);
    }
  }

  /// (high, low) to store, or (null, null) for AI-decides.
  (int?, int?) _repBounds() {
    final n = _sets ?? 4;
    switch (_repStyle) {
      case _RepStyle.pyramid:
        final low = (_topReps - 2 * (n - 1)).clamp(1, _topReps);
        return (_topReps, low);
      case _RepStyle.straight:
        return (_topReps, _topReps);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How do you train?',
                style: AppText.sectionTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              'Pick how you train — the AI builds the exercises around your sets and reps.',
              style: AppText.meta.copyWith(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 18),

            // ── Sets per exercise ─────────────────────────────
            Text('SETS PER EXERCISE', style: AppText.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in [2, 3, 4, 5])
                  _PrefChip(
                    label: '$n',
                    selected: _sets == n,
                    onTap: () => setState(() => _sets = n),
                  ),
                _PrefChip(
                  label: 'AI decides',
                  selected: _sets == null,
                  onTap: () => setState(() => _sets = null),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Rep scheme ────────────────────────────────────
            Text('REPS PER SET', style: AppText.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PrefChip(
                  label: 'Pyramid  ·  −2 / set',
                  selected: _repStyle == _RepStyle.pyramid,
                  onTap: () =>
                      setState(() => _repStyle = _RepStyle.pyramid),
                ),
                _PrefChip(
                  label: 'Straight  ·  same reps',
                  selected: _repStyle == _RepStyle.straight,
                  onTap: () =>
                      setState(() => _repStyle = _RepStyle.straight),
                ),
              ],
            ),

            // Top-reps picker + live per-set preview.
            ...[
              const SizedBox(height: 14),
              Text(
                _repStyle == _RepStyle.pyramid
                    ? 'TOP SET REPS'
                    : 'REPS EACH SET',
                style: AppText.label,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in [15, 12, 10, 8, 6, 5])
                    _PrefChip(
                      label: '$r',
                      selected: _topReps == r,
                      onTap: () => setState(() => _topReps = r),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Preview of the exact reps for each set.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EACH SET',
                        style: AppText.label
                            .copyWith(color: AppColors.accent, fontSize: 9)),
                    const SizedBox(height: 6),
                    Text(
                      _previewReps(_sets ?? 4).join('  ·  '),
                      style: AppText.sectionTitle.copyWith(fontSize: 20),
                    ),
                    if (_sets == null) ...[
                      const SizedBox(height: 4),
                      Text('(preview for 4 sets — AI picks the count)',
                          style: AppText.meta.copyWith(fontSize: 10)),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: AppText.body.copyWith(
                          color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    final (high, low) = _repBounds();
                    Navigator.of(context).pop(
                      _TrainingPrefs(
                        sets: _sets,
                        repsLow: low,
                        repsHigh: high,
                      ),
                    );
                  },
                  child: Text('Generate',
                      style: AppText.body.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PrefChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.stroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accent : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
