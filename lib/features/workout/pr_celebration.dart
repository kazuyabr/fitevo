import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Full-screen PR celebration — replaces the plain toast. A trophy pops
/// in with a shimmer, star particles burst out, and it auto-dismisses
/// after a couple of seconds (or tap to dismiss).
class PrCelebration {
  static void show(
    BuildContext context, {
    required String exerciseName,
    required double e1rm,
  }) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: true,
      builder: (_) => _PrDialog(exerciseName: exerciseName, e1rm: e1rm),
    );
  }
}

class _PrDialog extends StatefulWidget {
  final String exerciseName;
  final double e1rm;
  const _PrDialog({required this.exerciseName, required this.e1rm});

  @override
  State<_PrDialog> createState() => _PrDialogState();
}

class _PrDialogState extends State<_PrDialog> {
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _auto = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final e = widget.e1rm;
    final eStr = e == e.roundToDouble() ? e.toInt().toString() : e.toStringAsFixed(1);
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Star burst
            for (var i = 0; i < 8; i++)
              Icon(Icons.star_rounded,
                      color: AppColors.accent, size: 18 + (i % 3) * 6)
                  .animate()
                  .scale(
                      duration: 700.ms,
                      curve: Curves.easeOut,
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1))
                  .move(
                      duration: 700.ms,
                      curve: Curves.easeOut,
                      begin: Offset.zero,
                      end: Offset(
                        120 * (i.isEven ? 1 : -1) * ((i % 4) / 3 + 0.4),
                        120 * (i < 4 ? -1 : 1) * ((i % 3) / 2 + 0.4),
                      ))
                  .fadeOut(delay: 500.ms, duration: 400.ms),
            // Card
            Container(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded,
                          color: AppColors.accent, size: 64)
                      .animate()
                      .scale(
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                          begin: const Offset(0.2, 0.2),
                          end: const Offset(1, 1))
                      .shimmer(delay: 400.ms, duration: 900.ms),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.newPr,
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    widget.exerciseName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$eStr kg estimated 1RM',
                    style: AppText.meta.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ).animate().scale(
                duration: 400.ms,
                curve: Curves.easeOutBack,
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1)),
          ],
        ),
      ),
    );
  }
}
