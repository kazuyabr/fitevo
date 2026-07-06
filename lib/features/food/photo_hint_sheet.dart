import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/ai_icon.dart';

/// Shown right after the user takes/picks a food photo, BEFORE the AI
/// analyses it. Lets them optionally tell the AI what the food is and any
/// measured detail (e.g. "220 g grilled chicken breast, weighed") for a
/// far more accurate estimate. Leaving it blank is fine — the AI reads the
/// photo alone.
///
/// Returns the entered hint (possibly empty) when the user taps Analyze,
/// or null if they back out / cancel.
class PhotoHintSheet extends StatefulWidget {
  final String imagePath;
  final String? initialHint;
  const PhotoHintSheet({
    super.key,
    required this.imagePath,
    this.initialHint,
  });

  static Future<String?> show(
    BuildContext context, {
    required String imagePath,
    String? initialHint,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PhotoHintSheet(
        imagePath: imagePath,
        initialHint: initialHint,
      ),
    );
  }

  @override
  State<PhotoHintSheet> createState() => _PhotoHintSheetState();
}

class _PhotoHintSheetState extends State<PhotoHintSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialHint ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _analyze() => Navigator.of(context).pop(_ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    // Lift the sheet above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              // Photo preview
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(widget.imagePath),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 160,
                    color: AppColors.surfaceHigh,
                    alignment: Alignment.center,
                    child: Icon(Icons.image_rounded,
                        color: AppColors.textTertiary, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add details (optional)',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 4),
              Text(
                'Tell the AI what this is or its weight for a more accurate '
                'estimate — e.g. "220 g grilled chicken breast". Or leave it '
                'blank and the AI reads the photo on its own.',
                style: AppText.meta.copyWith(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _analyze(),
                minLines: 1,
                maxLines: 3,
                style: AppText.body.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. 220 g chicken breast, weighed',
                  hintStyle:
                      AppText.body.copyWith(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: AppColors.stroke),
                        ),
                        child: Text('Cancel',
                            style: AppText.body.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _analyze,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AiIcon(size: 18, color: AppColors.onAccent),
                            const SizedBox(width: 8),
                            Text('Analyze',
                                style: AppText.body.copyWith(
                                    color: AppColors.onAccent,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
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
