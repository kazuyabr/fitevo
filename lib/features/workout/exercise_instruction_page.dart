import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/ai_icon.dart';
import 'exercise_guide_sheet.dart';
import 'exercise_tutorial_page.dart';
import 'muscle_map_page.dart';
import 'plate_calculator_sheet.dart';

/// Full-screen workout overlay shown when the user starts an exercise.
///
/// Top half is the demo image (auto-cycles between start/end frames);
/// bottom half is a rounded card holding the timer, reps + weight input,
/// form cues, and Prev/Play/Next controls. Tapping the big centre Play
/// button logs the current set (via [onLog]) and advances to the next.
class ExerciseInstructionOverlay extends ConsumerStatefulWidget {
  final int exerciseId;
  final String exerciseName;
  final int setIndex;
  final int totalSets;
  final int completedSets;
  final int totalSetsAll;
  final DateTime workoutStartedAt;

  /// Reps + weight text controllers live in the parent (so the same
  /// values persist when the user taps Play to log the set).
  final TextEditingController weightController;
  final TextEditingController repsController;

  final VoidCallback onClose;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// Fired when the big centre Play button is tapped — parent should
  /// log the current set with the entered reps/weight, then advance.
  final VoidCallback onLog;

  /// Elapsed seconds this set had already accumulated before this mount.
  /// Powers the resume-timer behaviour: leaving and coming back to a
  /// set continues from where it stopped.
  final int initialElapsedSeconds;
  /// Fires every tick so the parent can persist the elapsed count and
  /// hand it back when this set is revisited.
  final void Function(int seconds)? onElapsedChanged;
  /// True while the parent's full-screen rest page covers this overlay —
  /// the set timer must not tick during rest or the next set would start
  /// with the whole rest period already on its clock.
  final bool suspended;

  /// RPE / reps-in-reserve for this set (null until the user picks one),
  /// and the set classification. Both are lifted to the parent so they
  /// survive set navigation and are written onto the SetEntry at log time.
  final double? rpe;
  final SetType setType;
  final ValueChanged<double?> onRpeChanged;
  final ValueChanged<SetType> onSetTypeChanged;

  /// Auto-progression coach line ("Add weight → 82.5 kg"), null when there's
  /// nothing to suggest. Tapping [onApplyCoach] fills the suggested values.
  final String? coachHeadline;
  final VoidCallback? onApplyCoach;

  const ExerciseInstructionOverlay({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.setIndex,
    required this.totalSets,
    required this.completedSets,
    required this.totalSetsAll,
    required this.workoutStartedAt,
    required this.weightController,
    required this.repsController,
    required this.onClose,
    required this.onPrev,
    required this.onNext,
    required this.onLog,
    this.initialElapsedSeconds = 0,
    this.onElapsedChanged,
    this.suspended = false,
    this.rpe,
    this.setType = SetType.normal,
    required this.onRpeChanged,
    required this.onSetTypeChanged,
    this.coachHeadline,
    this.onApplyCoach,
  });

  @override
  ConsumerState<ExerciseInstructionOverlay> createState() =>
      _ExerciseInstructionOverlayState();
}

class _ExerciseInstructionOverlayState
    extends ConsumerState<ExerciseInstructionOverlay> {
  Exercise? _exercise;
  List<String> _images = const [];
  bool _showSecond = false;
  Timer? _cycleTimer;
  Timer? _tickTimer;
  int _previewSeconds = 0;
  // Set timer auto-starts. User can pause via the big centre button.
  // Only the SET timer pauses — the workout TOTAL time keeps ticking.
  bool _setPlaying = true;

  // Video mode (bottom-right toggle) — off by default so images cycle
  // as before, video resolves on demand via ExerciseVideoService.
  bool _videoMode = false;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _muted = true;
  String? _resolvedVideoUrl;
  bool _videoControlsVisible = true;
  Timer? _controlsHideTimer;

  @override
  void initState() {
    super.initState();
    // Resume: pick up the elapsed count from the last visit to this set.
    _previewSeconds = widget.initialElapsedSeconds;
    _load();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Total-time chip refreshes from workoutStartedAt every tick, even
      // during pause. Set counter only advances while _setPlaying and
      // the rest page isn't covering us (suspended).
      final ticking = _setPlaying && !widget.suspended;
      setState(() {
        if (ticking) _previewSeconds++;
      });
      // Sync to parent so revisits resume from here.
      if (ticking) widget.onElapsedChanged?.call(_previewSeconds);
    });
  }

  Future<void> _load() async {
    final ex = await ref.read(exerciseRepoProvider).get(widget.exerciseId);
    List<String> imgs = const [];
    if (ex != null) {
      imgs = await ref
          .read(exerciseImageServiceProvider)
          .imagesFor(ex.name, max: 2);
    }
    if (!mounted) return;
    setState(() {
      _exercise = ex;
      _images = imgs;
    });
    if (imgs.length >= 2) {
      _cycleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        setState(() => _showSecond = !_showSecond);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ExerciseInstructionOverlay old) {
    super.didUpdateWidget(old);
    // Exercise changed while the widget stayed mounted (parent uses a
    // per-exercise key). Refetch the image + refresh the instructions —
    // without this the overlay would keep the previous exercise's assets.
    if (old.exerciseId != widget.exerciseId) {
      _cycleTimer?.cancel();
      _cycleTimer = null;
      setState(() {
        _exercise = null;
        _images = const [];
        _showSecond = false;
      });
      _load();
    }
    // Set changed — snap the set-timer to whatever the parent has saved
    // for the new set (0 for a fresh set, or the resume value from
    // _setElapsed on revisit). Prevents the previous set's seconds
    // bleeding into the new one.
    if (old.setIndex != widget.setIndex) {
      _previewSeconds = widget.initialElapsedSeconds;
    }
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _tickTimer?.cancel();
    _controlsHideTimer?.cancel();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _toggleVideoMode() async {
    if (_videoMode) {
      // Video → images: pause + drop the controller.
      await _videoCtrl?.pause();
      await _videoCtrl?.dispose();
      if (!mounted) return;
      setState(() {
        _videoMode = false;
        _videoReady = false;
        _videoCtrl = null;
      });
      return;
    }
    // Images → video: resolve URL then init the player.
    setState(() {
      _videoMode = true;
      _videoControlsVisible = true;
    });
    try {
      final url = await ref
          .read(exerciseVideoServiceProvider)
          .resolveStreamUrl(widget.exerciseName);
      if (!mounted) return;
      if (url == null) throw StateError('no video url');
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(_muted ? 0 : 1);
      await ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _videoCtrl = ctrl;
        _videoReady = true;
        _resolvedVideoUrl = url;
      });
      _scheduleHideControls();
    } catch (_) {
      // Resolve or init failed — silently fall back to image mode.
      if (!mounted) return;
      setState(() {
        _videoMode = false;
        _videoReady = false;
      });
    }
  }

  void _togglePlayVideo() {
    final c = _videoCtrl;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
      _videoControlsVisible = true;
    });
    _scheduleHideControls();
  }

  void _toggleMute() {
    final c = _videoCtrl;
    if (c == null) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
      _videoControlsVisible = true;
    });
    _scheduleHideControls();
  }

  void _tapVideoOverlay() {
    if (!_videoMode || !_videoReady) return;
    setState(() => _videoControlsVisible = !_videoControlsVisible);
    if (_videoControlsVisible) _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          _videoMode &&
          (_videoCtrl?.value.isPlaying ?? false)) {
        setState(() => _videoControlsVisible = false);
      }
    });
  }

  void _openFullscreenVideo() {
    // Pass the inline player's current position so fullscreen resumes
    // from there instead of restarting the clip from 0.
    final pos = _videoCtrl?.value.position ?? Duration.zero;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseTutorialPage(
          exerciseName: widget.exerciseName,
          initialUrl: _resolvedVideoUrl,
          startAt: pos,
        ),
      ),
    );
  }

  String _fmtSetTimer() {
    final m = _previewSeconds ~/ 60;
    final s = _previewSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtTotalTimer() {
    final elapsed =
        DateTime.now().difference(widget.workoutStartedAt).inSeconds;
    final m = (elapsed ~/ 60).clamp(0, 999);
    final s = elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double _weight() =>
      double.tryParse(widget.weightController.text.trim()) ?? 0;
  int _reps() => int.tryParse(widget.repsController.text.trim()) ?? 0;

  void _bumpWeight(double delta) {
    final next = (_weight() + delta).clamp(0.0, 999.0);
    setState(() {
      widget.weightController.text = next == next.roundToDouble()
          ? next.toInt().toString()
          : next.toStringAsFixed(1);
    });
  }

  void _bumpReps(int delta) {
    final next = (_reps() + delta).clamp(0, 999);
    setState(() {
      widget.repsController.text = next.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topH = mq.size.height * 0.44;
    final completedPct = widget.totalSetsAll == 0
        ? 0.0
        : (widget.completedSets / widget.totalSetsAll).clamp(0.0, 1.0);
    final pctInt = (completedPct * 100).round();
    final e = _exercise;

    return Positioned.fill(
      child: Material(
        color: AppColors.bg,
        child: Stack(
          children: [
            // ── Image / video zone (top half) ─────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topH,
              child: GestureDetector(
                onTap: _tapVideoOverlay,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Base layer — image cycle is always mounted; the
                    // video layer covers it when active so switching
                    // back is instant.
                    _ImageZone(
                        images: _images, showSecond: _showSecond),

                    // Video layer (letterboxed on black) when active.
                    if (_videoMode && _videoReady && _videoCtrl != null)
                      Container(
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _videoCtrl!.value.aspectRatio == 0
                                ? 16 / 9
                                : _videoCtrl!.value.aspectRatio,
                            child: VideoPlayer(_videoCtrl!),
                          ),
                        ),
                      ),

                    // Loading pill while the video is resolving —
                    // centred inside the image zone so it doesn't
                    // overlap the status bar at the top.
                    if (_videoMode && !_videoReady)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.accent),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Finding demo…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Bottom-right: image ↔ video toggle ─────
                    // Sits above the card overlap (topH - 24) so it's
                    // not hidden behind the rounded card top.
                    Positioned(
                      right: 12,
                      bottom: 40,
                      child: GestureDetector(
                        onTap: _toggleVideoMode,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color:
                                Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              _ModeChip(
                                  icon: Icons.image_outlined,
                                  active: !_videoMode),
                              _ModeChip(
                                  icon: Icons
                                      .play_circle_fill_rounded,
                                  active: _videoMode),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Video controls (bottom bar) ──────────────
                    if (_videoMode &&
                        _videoReady &&
                        _videoCtrl != null)
                      AnimatedOpacity(
                        opacity: _videoControlsVisible ? 1 : 0,
                        duration:
                            const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !_videoControlsVisible,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            // Full-width bar hugging the bottom of the
                            // image zone (above the toggle chip's row).
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  10, 0, 10, 84),
                              child: _VideoBar(
                                controller: _videoCtrl!,
                                muted: _muted,
                                onTogglePlay: _togglePlayVideo,
                                onToggleMute: _toggleMute,
                                onFullscreen: _openFullscreenVideo,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Top-left: TOTAL TIME + progress bar ──────────────
            // Top-left: vertical TOTAL TIME pill — clock icon on top,
            // TOTAL label in the middle, MM:SS timer below.
            Positioned(
              top: mq.padding.top + 14,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(height: 4),
                    const Text('TOTAL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      _fmtTotalTimer(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        height: 1.0,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Close button (top-right) ─────────────────────────
            // Hold to end workout — 2s press draws a progress ring, then
            // fires the parent's onClose (which itself shows a confirm
            // dialog before popping the workout page). Belt-and-suspenders
            // against accidental exits mid-set.
            Positioned(
              top: mq.padding.top + 16,
              right: 16,
              child: _HoldButton(
                duration: const Duration(seconds: 2),
                size: 54,
                ringColor: AppColors.accent,
                onHold: widget.onClose,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ),

            // ── Bottom card ──────────────────────────────────────
            Positioned(
              top: topH - 24,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      decoration: BoxDecoration(
                        color: AppColors.stroke,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fmtSetTimer(),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 46,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -2,
                                          height: 1.0,
                                          fontFamily: 'PlusJakartaSans',
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SET ${widget.setIndex + 1} OF ${widget.totalSets}',
                                        style: TextStyle(
                                          color:
                                              AppColors.textTertiary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Muscle map — shows which muscles this
                                // exercise trains.
                                GestureDetector(
                                  onTap: () => ExerciseMuscleSheet.show(
                                    context,
                                    exerciseName: widget.exerciseName,
                                    muscles:
                                        _exercise?.muscleGroups ?? const [],
                                  ),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    margin:
                                        const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceHigh,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AppColors.stroke),
                                    ),
                                    child: Icon(
                                      Icons.accessibility_new_rounded,
                                      color: AppColors.textSecondary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () =>
                                      ExerciseGuideSheet.show(
                                    context,
                                    exerciseId: widget.exerciseId,
                                    fallbackName: widget.exerciseName,
                                  ),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    margin:
                                        const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceHigh,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AppColors.stroke),
                                    ),
                                    child: Icon(
                                      Icons
                                          .format_list_bulleted_rounded,
                                      color: AppColors.textSecondary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Auto-progression coach line — tap to apply the
                            // suggested weight/reps to the inputs below.
                            if (widget.coachHeadline != null) ...[
                              const SizedBox(height: 12),
                              _CoachChip(
                                headline: widget.coachHeadline!,
                                onApply: widget.onApplyCoach,
                              ),
                            ],
                            const SizedBox(height: 14),
                            _RepsWeightRow(
                              weight: _weight(),
                              reps: _reps(),
                              onWeightBump: _bumpWeight,
                              onRepsBump: _bumpReps,
                              onOpenPlates: _weight() > 0
                                  ? () => PlateCalculatorSheet.show(
                                        context,
                                        targetKg: _weight(),
                                      )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            // Set type (warmup / working / drop / AMRAP /
                            // failure) — changes how the set counts.
                            _SetTypeRow(
                              value: widget.setType,
                              onChanged: widget.onSetTypeChanged,
                            ),
                            const SizedBox(height: 10),
                            // RPE / reps-in-reserve — how many reps were
                            // left in the tank. Feeds auto-progression.
                            _RpeRow(
                              value: widget.rpe,
                              onChanged: widget.onRpeChanged,
                            ),
                            const SizedBox(height: 14),
                            // Workout-completion progress: % on the left,
                            // filled bar on the right. Moved from the top
                            // overlay so it sits right below the input row.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.stroke),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '$pctInt%',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: completedPct,
                                        minHeight: 6,
                                        backgroundColor:
                                            AppColors.surface,
                                        valueColor: AlwaysStoppedAnimation(
                                            AppColors.accent),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'COMPLETED',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (e != null && e.formCues.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                widget.exerciseName,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final c in e.formCues)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(
                                            top: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          c,
                                          style: TextStyle(
                                            color: AppColors.textPrimary
                                                .withValues(alpha: 0.9),
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 8,
                        bottom: mq.padding.bottom + 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavButton(
                              icon: Icons.skip_previous_rounded,
                              label: 'Prev.',
                              onTap: widget.onPrev,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Big centre button pauses/resumes the SET
                          // timer only — total time keeps ticking.
                          // Hold-to-fire so an accidental tap doesn't
                          // pause/resume mid-set. No confirm dialog.
                          _HoldButton(
                            duration: const Duration(seconds: 1),
                            size: 92,
                            ringColor: Colors.white,
                            onHold: () => setState(
                                () => _setPlaying = !_setPlaying),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.45),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _setPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 34,
                                color: AppColors.onAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Next logs the current set via onLog. The parent's
                          // _logSet handler ALREADY advances the focus cursor
                          // (via _advanceFocusCursor) after saving — calling
                          // widget.onNext() on top of that skipped a set
                          // (double-advance bug: set 1 → set 3, or last set
                          // → next-exercise-set-2). If reps are empty _logSet
                          // no-ops so the cursor doesn't move, which is fine.
                          Expanded(
                            child: _NavButton(
                              icon: Icons.skip_next_rounded,
                              label: 'Next',
                              onTap: widget.onLog,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageZone extends StatelessWidget {
  final List<String> images;
  final bool showSecond;
  const _ImageZone(
      {required this.images, required this.showSecond});

  @override
  Widget build(BuildContext context) {
    // AnimatedCrossFade's default layoutBuilder anchors children to the
    // top and leaves them at their natural size, so a CachedNetworkImage
    // inside collapses to its intrinsic size instead of filling the
    // container. Override the layoutBuilder to Positioned.fill both
    // children so the photo actually fills the whole image zone.
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.surfaceHigh),
        if (images.isNotEmpty)
          AnimatedCrossFade(
            // Short enough that the double-exposure blend is barely visible.
            // 700ms was long enough that any screenshot mid-transition
            // looked like two exercises overlaid.
            duration: const Duration(milliseconds: 220),
            firstChild: _NetImg(url: images[0]),
            secondChild: _NetImg(
                url: images.length > 1 ? images[1] : images[0]),
            crossFadeState: showSecond
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            layoutBuilder: (topChild, topKey, bottomChild, bottomKey) =>
                Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(key: bottomKey, child: bottomChild),
                Positioned.fill(key: topKey, child: topChild),
              ],
            ),
          ),
        // Thin bottom fade only — start the gradient near the very bottom
        // (85% down) so the image fills the whole zone instead of getting
        // washed out through the middle.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(0, 0.88),
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppColors.surface],
            ),
          ),
        ),
      ],
    );
  }
}

class _NetImg extends StatelessWidget {
  final String url;
  const _NetImg({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (_, _) => Container(color: AppColors.surfaceHigh),
      errorWidget: (_, _, _) => Container(
        color: AppColors.surfaceHigh,
        alignment: Alignment.center,
        child: Icon(Icons.fitness_center_rounded,
            size: 40, color: AppColors.textTertiary),
      ),
    );
  }
}

class _RepsWeightRow extends StatelessWidget {
  final double weight;
  final int reps;
  final ValueChanged<double> onWeightBump;
  final ValueChanged<int> onRepsBump;
  /// Opens the plate loader for the current weight. Null (disabled) when
  /// weight is 0 — nothing to load.
  final VoidCallback? onOpenPlates;

  const _RepsWeightRow({
    required this.weight,
    required this.reps,
    required this.onWeightBump,
    required this.onRepsBump,
    this.onOpenPlates,
  });

  String _fmtWeight(double w) {
    if (w == w.roundToDouble()) return w.toInt().toString();
    return w.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NumberCard(
            label: 'WEIGHT (KG)',
            value: _fmtWeight(weight),
            onMinus: () => onWeightBump(-2.5),
            onPlus: () => onWeightBump(2.5),
            // Tapping the label opens the plate loader.
            trailing: onOpenPlates == null
                ? null
                : GestureDetector(
                    onTap: onOpenPlates,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.fitness_center_rounded,
                      size: 13,
                      color: AppColors.accent,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _NumberCard(
            label: 'REPS',
            value: reps.toString(),
            onMinus: () => onRepsBump(-1),
            onPlus: () => onRepsBump(1),
          ),
        ),
      ],
    );
  }
}

class _NumberCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final Widget? trailing;

  const _NumberCard({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _StepBtn(icon: Icons.remove_rounded, onTap: onMinus),
              Expanded(
                child: Center(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              _StepBtn(icon: Icons.add_rounded, onTap: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

/// Slim auto-progression coach line above the inputs. Tap to apply the
/// suggested weight/reps. Shows a lightning icon + the headline; the
/// "APPLY" affordance only appears when there's something to fill.
class _CoachChip extends StatelessWidget {
  final String headline;
  final VoidCallback? onApply;
  const _CoachChip({required this.headline, this.onApply});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onApply,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            AiIcon(size: 15, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (onApply != null) ...[
              const SizedBox(width: 8),
              Text(
                'APPLY',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal selector for the set type. "Work" (normal) is the default;
/// the others tag the set so it renders and counts differently.
class _SetTypeRow extends StatelessWidget {
  final SetType value;
  final ValueChanged<SetType> onChanged;
  const _SetTypeRow({required this.value, required this.onChanged});

  static const _labels = {
    SetType.warmup: 'Warm-up',
    SetType.normal: 'Working',
    SetType.dropSet: 'Drop',
    SetType.amrap: 'AMRAP',
    SetType.failure: 'Failure',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          for (final t in SetType.values) ...[
            _pill(t),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _pill(SetType t) {
    final active = t == value;
    return GestureDetector(
      onTap: () => onChanged(t),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.stroke,
          ),
        ),
        child: Text(
          _labels[t]!,
          style: TextStyle(
            color: active ? AppColors.onAccent : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Reps-in-reserve selector (0–5+). Lower = closer to failure. Feeds the
/// auto-progression advisor and stored as `rpe` on the set.
class _RpeRow extends StatelessWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  const _RpeRow({required this.value, required this.onChanged});

  // Map RIR taps to an RPE number (RPE = 10 - RIR) for storage.
  static const _options = [
    ('0', 10.0),
    ('1', 9.0),
    ('2', 8.0),
    ('3', 7.0),
    ('4+', 6.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'RIR',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        for (final o in _options) ...[
          Expanded(child: _chip(o.$1, o.$2)),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _chip(String label, double rpe) {
    final active = value == rpe;
    return GestureDetector(
      // Tap again to clear.
      onTap: () => onChanged(active ? null : rpe),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.stroke,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.accent : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Mode toggle chip (image ↔ video) ───────────────────────

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _ModeChip({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: active ? AppColors.accent : Colors.transparent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 15,
        color: active ? AppColors.onAccent : Colors.white,
      ),
    );
  }
}

// ─────────────────────── Video bottom bar ───────────────────────

class _VideoBar extends StatelessWidget {
  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onFullscreen;

  const _VideoBar({
    required this.controller,
    required this.muted,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onFullscreen,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTogglePlay,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 4),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, VideoPlayerValue value, _) => Text(
              _fmt(value.position),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Scrubbable progress bar takes ALL remaining space — the bar
          // spans full width so it doesn't visually cut the video mid.
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.accent,
                bufferedColor: Colors.white.withValues(alpha: 0.35),
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
              padding: const EdgeInsets.symmetric(vertical: 5),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggleMute,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          GestureDetector(
            onTap: onFullscreen,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: const Icon(
                Icons.fullscreen_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Hold-to-confirm button ───────────────────────

/// Wraps [child] and requires a hold-down gesture of [duration] before
/// firing [onHold]. Draws a circular progress ring around the child that
/// grows as the press is held. Prevents accidental taps on destructive
/// or intent-heavy actions.
class _HoldButton extends StatefulWidget {
  final Duration duration;
  final VoidCallback onHold;
  final double size;
  final Color ringColor;
  final Widget child;

  const _HoldButton({
    required this.duration,
    required this.onHold,
    required this.child,
    this.size = 44,
    required this.ringColor,
  });

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        // Fire once; user must release + re-press to fire again.
        widget.onHold();
        _ctrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _startHold() {
    _ctrl.forward();
  }

  void _cancelHold() {
    if (_ctrl.status == AnimationStatus.forward) _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            widget.child,
            // Progress ring on top of the child while held
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => IgnorePointer(
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    value: _ctrl.value,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(widget.ringColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
