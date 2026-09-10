import 'package:flutter/material.dart';

import '../../services/workout/plate_calculator.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet that shows how to load a barbell for a target weight.
/// Opened from the weight field in the logger so the user doesn't have
/// to do plate maths mid-set.
class PlateCalculatorSheet extends StatefulWidget {
  final double targetKg;
  const PlateCalculatorSheet({super.key, required this.targetKg});

  static Future<void> show(BuildContext context, {required double targetKg}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlateCalculatorSheet(targetKg: targetKg),
    );
  }

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  double _barKg = PlateCalculator.olympicBar;

  // Distinct colour per common plate so the bar reads at a glance —
  // loosely mirrors real calibrated-plate colours. (Non-const: Dart
  // forbids `double` keys in a const map.)
  static final Map<double, Color> _plateColors = {
    25: Color(0xFFE23B3B),
    20: Color(0xFF2E7DF6),
    15: Color(0xFFF5A524),
    10: Color(0xFF2Fb673),
    5: Color(0xFFB0B4BB),
    2.5: Color(0xFF8B5CF6),
    1.25: Color(0xFF64748B),
    0.5: Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final sol = PlateCalculator.solve(
      targetKg: widget.targetKg,
      barKg: _barKg,
    );
    return SafeArea(
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppLocalizations.of(context)!.plateLoader, style: AppText.sectionTitle),
                const Spacer(),
                Text(
                  '${_fmt(widget.targetKg)} kg',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sol.isExact
                  ? loc.loadEachSide
                  : loc.closestLoadable(_fmt(sol.loadedTotalKg)),
              style: TextStyle(
                color: sol.isExact
                    ? AppColors.textTertiary
                    : AppColors.water,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            // Visual barbell
            _BarbellView(solution: sol, plateColors: _plateColors),
            const SizedBox(height: 20),
            // Per-side breakdown chips
            if (sol.grouped.isEmpty)
              Text(
                loc.justBar,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in sol.grouped)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (_plateColors[g.weightKg] ?? AppColors.accent)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_plateColors[g.weightKg] ?? AppColors.accent)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '${g.count} × ${_fmt(g.weightKg)}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            Text(
              'BAR WEIGHT',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _barChip('Olympic', '20kg', PlateCalculator.olympicBar),
                const SizedBox(width: 8),
                _barChip('Women\'s', '15kg', PlateCalculator.womensBar),
                const SizedBox(width: 8),
                _barChip('EZ / short', '7.5kg', PlateCalculator.ezBar),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _barChip(String label, String sub, double value) {
    final active = (_barKg - value).abs() < 0.01;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _barKg = value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.accent : AppColors.stroke,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.onAccent : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  color: active
                      ? AppColors.onAccent.withValues(alpha: 0.85)
                      : AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double w) =>
      w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(2);
}

class _BarbellView extends StatelessWidget {
  final PlateSolution solution;
  final Map<double, Color> plateColors;
  const _BarbellView({required this.solution, required this.plateColors});

  @override
  Widget build(BuildContext context) {
    // Bigger plates render taller. Map each plate to a height band.
    double heightFor(double kg) {
      switch (kg) {
        case 25:
          return 88;
        case 20:
          return 80;
        case 15:
          return 70;
        case 10:
          return 58;
        case 5:
          return 46;
        case 2.5:
          return 36;
        default:
          return 28;
      }
    }

    Widget plate(double kg) => Container(
          width: 13,
          height: heightFor(kg),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: plateColors[kg] ?? AppColors.accent,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sleeve / bar end
          Container(
            width: 30,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          for (final p in solution.perSide) plate(p),
          // Collar
          Container(
            width: 6,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
