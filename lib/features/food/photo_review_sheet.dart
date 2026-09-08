import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../services/ai/ai_service.dart';
import '../../state/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';

/// Shows the AI's read of a food photo — what it thinks is on the plate and
/// the calorie / macro estimate — and lets the user confirm it or type a
/// correction ("3 rotis, the bowl is rice, add 1 egg") to recalculate before
/// anything is logged. Returns the confirmed [FoodAnalysis], or null if the
/// user backed out.
class PhotoReviewSheet extends ConsumerStatefulWidget {
  final String imagePath;
  final List<int> bytes;
  final FoodAnalysis initial;

  const PhotoReviewSheet({
    super.key,
    required this.imagePath,
    required this.bytes,
    required this.initial,
  });

  static Future<FoodAnalysis?> show(
    BuildContext context, {
    required String imagePath,
    required List<int> bytes,
    required FoodAnalysis initial,
  }) {
    return showModalBottomSheet<FoodAnalysis>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PhotoReviewSheet(
          imagePath: imagePath, bytes: bytes, initial: initial),
    );
  }

  @override
  ConsumerState<PhotoReviewSheet> createState() => _PhotoReviewSheetState();
}

class _PhotoReviewSheetState extends ConsumerState<PhotoReviewSheet> {
  late FoodAnalysis _analysis = widget.initial;
  final _fix = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _fix.dispose();
    super.dispose();
  }

  /// Plain-language "4 pieces Roti, 1 bowl Dal and a small salad".
  String _plateSummary() {
    final parts = _analysis.items
        .map((i) => '${i.quantity} ${i.name}'.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Nothing detected';
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }

  String _breakdownForHint() => _analysis.items
      .map((i) => '${i.quantity} ${i.name} (${i.calories} kcal)'.trim())
      .join(', ');

  Future<void> _recalculate() async {
    final fix = _fix.text.trim();
    if (fix.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    // Hand the model its current read + the user's correction so it refines
    // the whole plate rather than re-reading it from scratch.
    final hint = 'Your previous estimate for this photo was: '
        '${_breakdownForHint()}. The user corrects it: "$fix". '
        'Re-estimate the full plate accordingly.';
    try {
      final updated = await ref
          .read(foodLoggerProvider)
          .analyzePhoto(widget.bytes, hint: hint);
      if (!mounted) return;
      if (updated.items.isEmpty) {
        _snack('Couldn\'t recalculate from that — try rephrasing.');
      } else {
        setState(() {
          _analysis = updated;
          _fix.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        _snack(e is AiException ? e.message : 'Could not recalculate.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content:
            Text(m, style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final items = _analysis.items;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(widget.imagePath),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Analyzed Food'.toUpperCase(),
                            style: AppText.label.copyWith(
                                color: AppColors.accent,
                                fontSize: 10,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 4),
                        Text(_plateSummary(),
                            style: AppText.body.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${items[i].quantity} ${items[i].name}'.trim(),
                                style: AppText.body.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (items[i].confidence == EstimateConfidence.low)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text('≈',
                                    style: TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 13)),
                              ),
                            Text('${items[i].calories} kcal',
                                style: AppText.body.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accent)),
                          ],
                        ),
                      ),
                      if (i < items.length - 1)
                        Divider(height: 1, color: AppColors.stroke),
                    ],
                    const SizedBox(height: 10),
                    Container(height: 1, color: AppColors.stroke),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(loc.totalMacros.toUpperCase(), style: AppText.label),
                        const Spacer(),
                        Text('${_analysis.totalCalories} kcal',
                            style: AppText.sectionTitle.copyWith(fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'P ${_analysis.totalProteinG}g   ·   '
                      'C ${_analysis.totalCarbsG}g   ·   '
                      'F ${_analysis.totalFatG}g   ·   '
                      'Fiber ${_analysis.totalFiberG}g',
                      style: AppText.meta.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Not Quite Right'.toUpperCase(), style: AppText.label),
              const SizedBox(height: 6),
              Text('Tell me what to fix and I\'ll recalculate.',
                  style: AppText.meta.copyWith(fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stroke),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _fix,
                  enabled: !_busy,
                  minLines: 1,
                  maxLines: 3,
                  cursorColor: AppColors.accent,
                  style: AppText.body
                      .copyWith(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                    hintText: 'e.g. 3 rotis, the bowl is rice, add 1 boiled egg',
                  ),
                  onSubmitted: (_) => _recalculate(),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _busy ? null : _recalculate,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: AppColors.accent))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(loc.retry,
                                style: AppText.body.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _busy ? null : () => Navigator.of(context).pop(_analysis),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(loc.confirmFood,
                      style: AppText.body.copyWith(
                          color: AppColors.onAccent,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
