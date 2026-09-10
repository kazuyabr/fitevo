// ignore_for_file: use_null_aware_elements
// isar_generator's bundled analyzer can't parse `?value` yet, so we use
// the equivalent `if (value != null)` form instead.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/exercise.dart';
import '../../data/models/routine.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/skeleton.dart';
import 'exercise_tutorial_page.dart';
import '../../l10n/app_localizations.dart';

/// Beautiful exercise detail: START + END frames side-by-side (so the
/// user sees the full range of motion), then muscle/equipment tags,
/// target sets/reps/rest, form cues, and common mistakes.
class ExerciseDetailPage extends ConsumerStatefulWidget {
  final int exerciseId;
  final RoutinePlanItem? planItem;

  const ExerciseDetailPage({
    super.key,
    required this.exerciseId,
    this.planItem,
  });

  @override
  ConsumerState<ExerciseDetailPage> createState() =>
      _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  Exercise? _exercise;
  List<String> _images = const [];
  bool _loading = true;
  // Started as soon as we know the exercise name so the video URL is
  // usually already resolved by the time the user taps the toggle — no
  // 5+ second wait staring at a spinner.
  Future<String?>? _videoFuture;

  @override
  void initState() {
    super.initState();
    _load();
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
      _loading = false;
      if (ex != null) {
        _videoFuture ??= ref
            .read(exerciseVideoServiceProvider)
            .resolveStreamUrl(ex.name);
      }
    });
  }

  String _label(String n) =>
      n.isEmpty ? n : n[0].toUpperCase() + n.substring(1);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final e = _exercise;
    final item = widget.planItem;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          e?.name ?? 'Exercise',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.sectionTitle.copyWith(fontSize: 17),
        ),
      ),
      body: _loading
          ? const _DetailSkeleton()
          : e == null
              ? _MissingExercise()
              : SafeArea(
                  top: false,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    physics: const ClampingScrollPhysics(),
                    children: [
                      // ── START + END frames (+ optional video) ─────
                      // Toggle in the top-right of the frame flips to
                      // video mode; the resolver runs a live YouTube
                      // search (or hits the Pexels curated map first).
                      _FramesRow(
                        images: _images,
                        exerciseName: e.name,
                        // Reuse the prefetch kicked off in _load so the
                        // future is (often) already resolved by tap time.
                        resolveVideoUrl: () =>
                            _videoFuture ??= ref
                                .read(exerciseVideoServiceProvider)
                                .resolveStreamUrl(e.name),
                      )
                          .animate()
                          .fadeIn(duration: 260.ms),
                      const SizedBox(height: 18),

                      // ── Title (again, big) ────────────────────────
                      Text(
                        e.name,
                        style: AppText.giantNumber.copyWith(
                          fontSize: 26,
                          height: 1.1,
                          letterSpacing: -0.6,
                        ),
                      ).animate().fadeIn(delay: 80.ms, duration: 260.ms),
                      const SizedBox(height: 12),

                      // ── Muscle + equipment + beginner tags ────────
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final m in e.muscleGroups)
                            _Tag(
                                label: _label(m.name),
                                color: AppColors.accent),
                          _Tag(
                              label: _label(e.equipment.name),
                              color: AppColors.water),
                          if (e.isBeginnerFriendly)
                            _Tag(
                                label: AppLocalizations.of(context)!.beginnerFriendly,
                                color: AppColors.protein),
                        ],
                      ).animate().fadeIn(
                          delay: 140.ms, duration: 260.ms),

                      // ── Target sets × reps + rest (from plan) ─────
                      if (item != null) ...[
                        const SizedBox(height: 18),
                        _TargetsRow(item: item)
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 260.ms),
                      ],

                      // ── FORM CUES ─────────────────────────────────
                      if (e.formCues.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionHeader(
                          label: AppLocalizations.of(context)!.formCues,
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 10),
                        for (final c in e.formCues)
                          _BulletRow(
                              text: c, color: AppColors.accent),
                      ],

                      // ── COMMON MISTAKES ───────────────────────────
                      if (e.commonMistakes.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionHeader(
                          label: AppLocalizations.of(context)!.commonMistakes,
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: 10),
                        for (final m in e.commonMistakes)
                          _BulletRow(
                            text: m,
                            color: AppColors.danger,
                            icon: Icons.close_rounded,
                          ),
                      ],

                      // ── Rest card ─────────────────────────────────
                      const SizedBox(height: 24),
                      _RestCard(
                        seconds:
                            item?.restSeconds ?? e.defaultRestSeconds,
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─────────────────────── START + END frames ───────────────────────

class _FramesRow extends StatefulWidget {
  final List<String> images;
  /// Resolves the playable video URL when the user toggles to video
  /// mode. Kept async so the parent can do a YouTube search / stream
  /// extract on demand — the toggle shows a spinner while it resolves.
  final Future<String?> Function()? resolveVideoUrl;
  /// Exercise name used as the fullscreen player's title.
  final String? exerciseName;
  const _FramesRow({
    required this.images,
    this.resolveVideoUrl,
    this.exerciseName,
  });

  @override
  State<_FramesRow> createState() => _FramesRowState();
}

class _FramesRowState extends State<_FramesRow> {
  int _index = 0;
  Timer? _timer;

  // Video mode
  bool _videoMode = false;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _muted = true;
  String? _resolvedUrl; // remembered so fullscreen can skip re-search
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;

  void _togglePlay() {
    final c = _videoCtrl;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
      _controlsVisible = true;
    });
    _scheduleHideControls();
  }

  void _toggleMute() {
    final c = _videoCtrl;
    if (c == null) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
      _controlsVisible = true;
    });
    _scheduleHideControls();
  }

  void _tapVideoOverlay() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoMode && (_videoCtrl?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _openFullscreen() {
    // Pass the inline player's current position so fullscreen resumes
    // from there instead of restarting the clip from 0.
    final pos = _videoCtrl?.value.position ?? Duration.zero;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseTutorialPage(
          exerciseName: widget.exerciseName ?? 'Tutorial',
          initialUrl: _resolvedUrl,
          startAt: pos,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncTimer();
    _maybeAutoStartVideo();
  }

  @override
  void didUpdateWidget(_FramesRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length) {
      _syncTimer();
      _maybeAutoStartVideo();
    }
  }

  /// If we don't have any demo images but we do have a way to resolve a
  /// video, skip the empty placeholder and jump straight into video mode
  /// so the user sees an actual demo instead of a "no images" card.
  void _maybeAutoStartVideo() {
    if (_videoMode || _videoCtrl != null) return;
    if (widget.images.isNotEmpty) return;
    if (widget.resolveVideoUrl == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_videoMode) _toggleVideo();
    });
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (_videoMode || widget.images.length < 2) return;
    // Cycle between start (index 0) and end (index 1) every 1 second so
    // the user gets an animated feel for the exercise range of motion —
    // a "poor man's GIF" built from the two frames free-exercise-db ships.
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.images.length);
    });
  }

  Future<void> _toggleVideo() async {
    if (widget.resolveVideoUrl == null) return;
    if (_videoMode) {
      // Back to images: pause & drop the video, restart the image timer.
      await _videoCtrl?.pause();
      await _videoCtrl?.dispose();
      if (!mounted) return;
      setState(() {
        _videoMode = false;
        _videoReady = false;
        _videoCtrl = null;
      });
      _syncTimer();
      return;
    }
    // Switch to video: cancel image timer, resolve URL, then init.
    _timer?.cancel();
    _timer = null;
    setState(() {
      _videoMode = true;
      _controlsVisible = true;
    });
    try {
      final url = await widget.resolveVideoUrl!();
      if (!mounted) return;
      if (url == null) throw StateError('no video url');
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      await ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _videoCtrl = ctrl;
        _videoReady = true;
        _resolvedUrl = url;
      });
      _scheduleHideControls();
    } catch (_) {
      // Video engine unavailable / URL failed — silently fall back to
      // the image cycle so the user isn't stuck on a black frame.
      if (!mounted) return;
      setState(() {
        _videoMode = false;
        _videoReady = false;
      });
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controlsHideTimer?.cancel();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (widget.images.isEmpty && widget.resolveVideoUrl == null) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 32, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.noDemoAvailable,
                style: AppText.meta.copyWith(fontSize: 12)),
          ],
        ),
      );
    }

    final hasImages = widget.images.isNotEmpty;
    final hasVideo = widget.resolveVideoUrl != null;
    final url = hasImages
        ? widget.images[_index % widget.images.length]
        : null;
    final isFirst = hasImages && _index % widget.images.length == 0;
    final showDots = hasImages && widget.images.length >= 2 && !_videoMode;
    final label = _videoMode
        ? 'VIDEO'
        : (widget.images.length >= 2
            ? (isFirst ? AppLocalizations.of(context)!.start : 'END')
            : 'DEMO');

    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Image layer (always rendered when we have images) ─────
          // Keeps something visible during video resolution so the frame
          // never blanks out — much better than staring at a spinner.
          if (url != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: KeyedSubtree(
                key: ValueKey(url),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textTertiary),
                ),
              ),
            ),

          // ── Video layer (letterboxed, on top of the image) ─────────
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

          // ── Loading pill overlay (image visible underneath) ────────
          if (_videoMode && !_videoReady)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loc.findingDemo,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom fade for label legibility (image mode only) ────
          if (!_videoMode)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),

          // ── Label chip (image mode only) ──────────────────────────
          if (!_videoMode)
            Positioned(
              left: 12,
              bottom: 12,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(label),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),

          // ── Video controls (only in video mode, when ready) ───────
          if (_videoMode && _videoReady && _videoCtrl != null) ...[
            // Tap catcher: toggle controls visibility on tap-anywhere.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tapVideoOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            // Big play/pause pulse in the centre when controls visible.
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _videoCtrl!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
            // Bottom bar: progress + time + fullscreen button.
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _VideoBottomBar(
                    controller: _videoCtrl!,
                    onFullscreen: _openFullscreen,
                    onToggleMute: _toggleMute,
                    muted: _muted,
                  ),
                ),
              ),
            ),
          ],

          // ── Image / Video mode toggle (top-right) ─────────────────
          if (hasVideo && hasImages)
            Positioned(
              top: 10,
              right: 10,
              child: _ModeToggle(
                videoMode: _videoMode,
                onTap: _toggleVideo,
              ),
            ),

          // ── Progress dots (image mode only) ───────────────────────
          if (showDots)
            Positioned(
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  for (int i = 0; i < widget.images.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: _index % widget.images.length == i ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                            alpha: _index % widget.images.length == i
                                ? 1
                                : 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────── Mode toggle (image / video) ───────────────────────

class _ModeToggle extends StatelessWidget {
  final bool videoMode;
  final VoidCallback onTap;
  const _ModeToggle({required this.videoMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _ModeChip(
              icon: Icons.image_outlined,
              active: !videoMode,
            ),
            _ModeChip(
              icon: Icons.play_circle_fill_rounded,
              active: videoMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _ModeChip({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? AppColors.accent : Colors.transparent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 16,
        color: active ? AppColors.onAccent : Colors.white,
      ),
    );
  }
}

// ─────────────────────── Video bottom bar ───────────────────────

class _VideoBottomBar extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullscreen;
  final VoidCallback onToggleMute;
  final bool muted;

  const _VideoBottomBar({
    required this.controller,
    required this.onFullscreen,
    required this.onToggleMute,
    required this.muted,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrubbable progress bar
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: AppColors.accent,
              bufferedColor: Colors.white.withValues(alpha: 0.35),
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
          // Time + fullscreen row
          Row(
            children: [
              const SizedBox(width: 4),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, VideoPlayerValue value, _) => Text(
                  '${_fmt(value.position)} / ${_fmt(value.duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onToggleMute,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onFullscreen,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Tag chip ───────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────── Targets row (sets × reps · rest) ─────────

class _TargetsRow extends StatelessWidget {
  final RoutinePlanItem item;
  const _TargetsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TargetCell(
              label: loc.sets,
              value: '${item.targetSets}',
              icon: Icons.repeat_rounded,
              color: AppColors.accent,
            ),
          ),
          _VDivider(),
          Expanded(
            child: _TargetCell(
              label: loc.reps,
              value: '${item.targetRepsLow}-${item.targetRepsHigh}',
              icon: Icons.trending_up_rounded,
              color: AppColors.protein,
            ),
          ),
          _VDivider(),
          Expanded(
            child: _TargetCell(
              label: AppLocalizations.of(context)!.rest,
              value: '${item.restSeconds}s',
              icon: Icons.timer_outlined,
              color: AppColors.water,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _TargetCell(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppText.label.copyWith(fontSize: 10, letterSpacing: 1.0),
        ),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: AppColors.stroke);
  }
}

// ─────────────────────── Section header ───────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppText.label.copyWith(letterSpacing: 1.4),
        ),
      ],
    );
  }
}

// ─────────────────────── Bullet row ───────────────────────

class _BulletRow extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _BulletRow(
      {required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 14, color: color),
                )
              : Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Rest card ───────────────────────

class _RestCard extends StatelessWidget {
  final int seconds;
  const _RestCard({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Rest ${seconds}s between working sets',
              style: AppText.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Missing / loading ───────────────────────

class _MissingExercise extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.exerciseNotFound1,
                style: AppText.sectionTitle.copyWith(fontSize: 17)),
            const SizedBox(height: 6),
            Text(AppLocalizations.of(context)!.thisExerciseMayHaveBeenRemovedFromYourLibrary,
                textAlign: TextAlign.center, style: AppText.body),
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 220)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 220)),
            ],
          ),
          const SizedBox(height: 18),
          const SkeletonBox(width: 240, height: 28),
          const SizedBox(height: 12),
          const SkeletonBox(width: 180, height: 20),
          const SizedBox(height: 18),
          const SkeletonSection(rows: 3, titleWidth: 120),
          const SizedBox(height: 14),
          const SkeletonSection(rows: 2, titleWidth: 160),
        ],
      ),
    );
  }
}
