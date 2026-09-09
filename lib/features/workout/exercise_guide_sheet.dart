import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/exercise.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

class ExerciseGuideSheet extends ConsumerStatefulWidget {
  final int exerciseId;
  final String fallbackName;

  const ExerciseGuideSheet({
    super.key,
    required this.exerciseId,
    required this.fallbackName,
  });

  static Future<void> show(
    BuildContext context, {
    required int exerciseId,
    required String fallbackName,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => ExerciseGuideSheet(
        exerciseId: exerciseId,
        fallbackName: fallbackName,
      ),
    );
  }

  @override
  ConsumerState<ExerciseGuideSheet> createState() =>
      _ExerciseGuideSheetState();
}

class _ExerciseGuideSheetState extends ConsumerState<ExerciseGuideSheet> {
  Exercise? _exercise;
  List<String> _images = const [];
  bool _loading = true;

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final h = MediaQuery.of(context).size.height;
    return SizedBox(
      height: h * 0.78,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: AppColors.accent),
                    ),
                  ),
                )
              else
                Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final e = _exercise;
    if (e == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.fallbackName,
                style: AppText.sectionTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.noFormGuideSavedForThisExerciseYet,
                textAlign: TextAlign.center, style: AppText.body),
          ],
        ),
      );
    }

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (_images.isNotEmpty) ...[
          Row(
            children: [
              for (var i = 0; i < _images.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: _images[i],
                      height: 160,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, _) => Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
        Text(e.name,
            style: AppText.giantNumber.copyWith(
              fontSize: 26,
              height: 1.1,
              letterSpacing: -0.6,
            )),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in e.muscleGroups)
              _Tag(label: _label(m.name), color: AppColors.accent),
            _Tag(label: _label(e.equipment.name), color: AppColors.water),
            if (e.isBeginnerFriendly)
              _Tag(label: AppLocalizations.of(context)!.beginnerFriendly, color: AppColors.protein),
          ],
        ),
        if (e.formCues.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(AppLocalizations.of(context)!.formCues, style: AppText.label),
          const SizedBox(height: 8),
          for (final c in e.formCues) _BulletRow(text: c, color: AppColors.accent),
        ],
        if (e.commonMistakes.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(AppLocalizations.of(context)!.commonMistakes, style: AppText.label),
          const SizedBox(height: 8),
          for (final m in e.commonMistakes)
            _BulletRow(text: m, color: AppColors.danger, icon: Icons.warning_amber_rounded),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Default rest: ${e.defaultRestSeconds}s',
                  style: AppText.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _label(String n) => n[0].toUpperCase() + n.substring(1);
}

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
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
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
