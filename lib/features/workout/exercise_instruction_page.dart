import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/exercise.dart';
import '../../state/providers.dart';
import '../../theme.dart';

class ExerciseInstructionPage extends ConsumerStatefulWidget {
  final int exerciseId;
  final String exerciseName;
  final int setIndex;
  final int totalSets;
  final int repsLow;
  final int repsHigh;

  const ExerciseInstructionPage({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.setIndex,
    required this.totalSets,
    required this.repsLow,
    required this.repsHigh,
  });

  @override
  ConsumerState<ExerciseInstructionPage> createState() =>
      _ExerciseInstructionPageState();
}

class _ExerciseInstructionPageState
    extends ConsumerState<ExerciseInstructionPage> {
  Exercise? _exercise;
  List<String> _images = const [];
  bool _showSecond = false;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final ex =
        await ref.read(exerciseRepoProvider).get(widget.exerciseId);
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
    if (imgs.length >= 2) _startCycle();
  }

  void _startCycle() {
    _cycleTimer =
        Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() => _showSecond = !_showSecond);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topH = mq.size.height * 0.50;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Image zone ─────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topH,
            child: _ImageZone(
              images: _images,
              showSecond: _showSecond,
            ),
          ),

          // ── Content card ───────────────────────────────────────────
          Positioned(
            top: topH - 32,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.stroke,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: _ContentSection(
                        exerciseName: widget.exerciseName,
                        setIndex: widget.setIndex,
                        totalSets: widget.totalSets,
                        repsLow: widget.repsLow,
                        repsHigh: widget.repsHigh,
                        exercise: _exercise,
                      ),
                    ),
                  ),
                  // Start button
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        24, 8, 24, mq.padding.bottom + 16),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Start Set ${widget.setIndex + 1}',
                          style: TextStyle(
                            color: AppColors.onAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Close button ───────────────────────────────────────────
          Positioned(
            top: mq.padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image zone: cycles between 2 images to simulate motion ──────────────────

class _ImageZone extends StatelessWidget {
  final List<String> images;
  final bool showSecond;

  const _ImageZone({required this.images, required this.showSecond});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Placeholder / background
        Container(color: AppColors.surfaceHigh),

        if (images.isNotEmpty)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 360),
            crossFadeState: showSecond && images.length >= 2
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _Img(url: images[0]),
            secondChild:
                _Img(url: images.length >= 2 ? images[1] : images[0]),
            layoutBuilder: (top, _, bottom, _) => Stack(
              fit: StackFit.expand,
              children: [bottom, top],
            ),
          ),

        // Bottom gradient blending into page background
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 100,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.bg,
                ],
              ),
            ),
          ),
        ),

        // Image counter dots (only when 2 images available)
        if (images.length >= 2)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Dot(active: !showSecond),
                const SizedBox(width: 5),
                _Dot(active: showSecond),
              ],
            ),
          ),
      ],
    );
  }
}

class _Img extends StatelessWidget {
  final String url;
  const _Img({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) =>
            Container(color: AppColors.surfaceHigh),
        errorWidget: (_, _, _) => Container(
          color: AppColors.surface,
          child: Icon(Icons.fitness_center_rounded,
              size: 48, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active
            ? Colors.white
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ── Content section ──────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  final String exerciseName;
  final int setIndex;
  final int totalSets;
  final int repsLow;
  final int repsHigh;
  final Exercise? exercise;

  const _ContentSection({
    required this.exerciseName,
    required this.setIndex,
    required this.totalSets,
    required this.repsLow,
    required this.repsHigh,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exerciseName,
          style: AppText.giantNumber.copyWith(
            fontSize: 26,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Set ${setIndex + 1} of $totalSets  ·  '
          '$repsLow${repsHigh != repsLow ? "–$repsHigh" : ""} reps',
          style: AppText.meta.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        if (e != null && e.muscleGroups.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in e.muscleGroups)
                _Chip(
                    label: _cap(m.name), color: AppColors.accent),
              _Chip(
                  label: _cap(e.equipment.name),
                  color: AppColors.water),
            ],
          ),
        ],
        if (e != null && e.formCues.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('FORM CUES', style: AppText.label),
          const SizedBox(height: 10),
          for (final c in e.formCues)
            _BulletRow(text: c, color: AppColors.accent),
        ],
        if (e != null && e.commonMistakes.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('COMMON MISTAKES', style: AppText.label),
          const SizedBox(height: 10),
          for (final m in e.commonMistakes)
            _BulletRow(
              text: m,
              color: AppColors.danger,
              icon: Icons.warning_amber_rounded,
            ),
        ],
        if (e != null &&
            e.formCues.isEmpty &&
            e.commonMistakes.isEmpty) ...[
          const SizedBox(height: 16),
          Text('No form guide saved for this exercise yet.',
              style: AppText.body),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

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

class _BulletRow extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _BulletRow({required this.text, required this.color, this.icon});

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
            child: Text(text,
                style: AppText.body.copyWith(
                    color: AppColors.textPrimary, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
