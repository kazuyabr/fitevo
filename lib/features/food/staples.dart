import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/custom_food.dart';
import '../../data/models/food_combo.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import 'combo_builder_page.dart';
import 'custom_foods_page.dart';

// ─── shared helpers ─────────────────────────────────────────────────────────

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      backgroundColor: AppColors.surfaceHigh,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Text(msg,
          style: AppText.body.copyWith(color: AppColors.textPrimary)),
    ));
}

String _fmtServings(double s) =>
    s == s.roundToDouble() ? '${s.toInt()}×' : '${s.toStringAsFixed(1)}×';

Future<void> _logFood(BuildContext context, WidgetRef ref, CustomFood food,
    {double servings = 1.0}) async {
  try {
    final entry =
        await ref.read(nutritionRepoProvider).logCustomFood(food, servings);
    if (!context.mounted) return;
    final label = servings == 1.0
        ? food.name
        : '${_fmtServings(servings)} ${food.name}';
    _toast(context, 'Logged $label · ${entry.calories} kcal');
  } catch (_) {
    if (context.mounted) _toast(context, 'Could not log that.');
  }
}

Future<void> _logCombo(
    BuildContext context, WidgetRef ref, FoodCombo combo) async {
  try {
    final r = await ref.read(nutritionRepoProvider).logCombo(combo);
    if (!context.mounted) return;
    if (r.logged == 0) {
      _toast(context, 'Nothing to log — this combo\'s foods were removed.');
    } else {
      _toast(context,
          'Logged ${combo.name} · ${r.logged} items · ${r.calories} kcal');
    }
  } catch (_) {
    if (context.mounted) _toast(context, 'Could not log that.');
  }
}

/// Long-press a food chip → pick a multiple before logging.
Future<void> _pickServings(
    BuildContext context, WidgetRef ref, CustomFood food) async {
  final choice = await showModalBottomSheet<double>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Grabber(),
            const SizedBox(height: 16),
            Text('How much ${food.name}?', style: AppText.sectionTitle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [0.5, 1.0, 1.5, 2.0, 3.0]
                  .map((s) => GestureDetector(
                        onTap: () => Navigator.pop(ctx, s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.stroke),
                          ),
                          child: Text(_fmtServings(s),
                              style: AppText.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice != null && context.mounted) {
    await _logFood(context, ref, food, servings: choice);
  }
}

/// Sheet offering "New food" / "New combo", then pushes the right builder.
Future<void> openStapleAddMenu(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Grabber(),
            const SizedBox(height: 18),
            _AddMenuRow(
              icon: Icons.restaurant_rounded,
              title: 'New food',
              subtitle: 'A single staple — shake, oats, eggs…',
              onTap: () => Navigator.pop(ctx, 'food'),
            ),
            const SizedBox(height: 10),
            _AddMenuRow(
              icon: Icons.layers_rounded,
              title: 'New combo',
              subtitle: 'Your usual stack, logged in one tap',
              onTap: () => Navigator.pop(ctx, 'combo'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  await Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) =>
        choice == 'combo' ? const ComboBuilderPage() : const CustomFoodForm(),
  ));
}

Future<void> _comboMenu(
    BuildContext context, WidgetRef ref, FoodCombo combo) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Grabber(),
            const SizedBox(height: 16),
            Text(combo.name, style: AppText.sectionTitle),
            const SizedBox(height: 16),
            _AddMenuRow(
              icon: Icons.edit_rounded,
              title: 'Edit combo',
              subtitle: 'Change foods or servings',
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            const SizedBox(height: 10),
            _AddMenuRow(
              icon: Icons.delete_outline_rounded,
              title: 'Delete combo',
              subtitle: 'Remove this stack',
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'edit') {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ComboBuilderPage(initial: combo),
    ));
  } else if (choice == 'delete') {
    await ref.read(nutritionRepoProvider).deleteCombo(combo.id);
    if (context.mounted) _toast(context, 'Combo deleted');
  }
}

Future<void> _foodMenu(
    BuildContext context, WidgetRef ref, CustomFood food) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Grabber(),
            const SizedBox(height: 16),
            Text(food.name, style: AppText.sectionTitle),
            const SizedBox(height: 16),
            _AddMenuRow(
              icon: Icons.tune_rounded,
              title: 'Log a different amount',
              subtitle: '½×, 2×, 3×…',
              onTap: () => Navigator.pop(ctx, 'amount'),
            ),
            const SizedBox(height: 10),
            _AddMenuRow(
              icon: Icons.edit_rounded,
              title: 'Edit food',
              subtitle: 'Change name or nutrition',
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            const SizedBox(height: 10),
            _AddMenuRow(
              icon: Icons.delete_outline_rounded,
              title: 'Delete food',
              subtitle: 'Remove from your staples',
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'amount') {
    await _pickServings(context, ref, food);
  } else if (choice == 'edit') {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CustomFoodForm(initial: food),
    ));
  } else if (choice == 'delete') {
    await ref.read(nutritionRepoProvider).deleteCustomFood(food.id);
    if (context.mounted) _toast(context, 'Food deleted');
  }
}

/// Foods sorted most-logged-first (ties: most-recent, then name).
List<CustomFood> _sortedFoods(List<CustomFood> foods) {
  final out = List<CustomFood>.of(foods);
  out.sort((a, b) {
    final byUse = b.useCount.compareTo(a.useCount);
    if (byUse != 0) return byUse;
    final byRecent =
        (b.lastUsedAt ?? DateTime(0)).compareTo(a.lastUsedAt ?? DateTime(0));
    if (byRecent != 0) return byRecent;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}

// ─── dashboard quick-add strip ───────────────────────────────────────────────

/// Horizontal strip of the user's saved staples for one-tap logging. Combos
/// come first (log the whole stack), then foods by frequency. Renders nothing
/// when there are no staples — no empty "+" card. Adding new staples is done
/// from the "See all" manager page.
class StaplesQuickAddStrip extends ConsumerWidget {
  const StaplesQuickAddStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combos = ref.watch(foodCombosProvider).valueOrNull ?? const [];
    final foods =
        _sortedFoods(ref.watch(customFoodsProvider).valueOrNull ?? const []);
    if (combos.isEmpty && foods.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: combos.length + foods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i < combos.length) {
            final c = combos[i];
            return _StapleChip(
              label: c.name,
              trailing: '${c.items.length}',
              icon: Icons.layers_rounded,
              highlight: true,
              onTap: () => _logCombo(context, ref, c),
              onLongPress: () => _comboMenu(context, ref, c),
            );
          }
          final f = foods[i - combos.length];
          return _StapleChip(
            label: f.name,
            trailing: '${f.caloriesPerServing}',
            onTap: () => _logFood(context, ref, f),
            onLongPress: () => _foodMenu(context, ref, f),
          );
        },
      ),
    );
  }
}

class _StapleChip extends StatelessWidget {
  final String label;
  final String trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final bool highlight;
  const _StapleChip({
    required this.label,
    required this.trailing,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: highlight
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.stroke),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: AppColors.accent),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: AppText.body.copyWith(
                    color: highlight ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const SizedBox(width: 6),
            Text(trailing,
                style: AppText.meta.copyWith(
                    color: highlight
                        ? AppColors.accent.withValues(alpha: 0.7)
                        : AppColors.textTertiary,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── "See all" manager page ──────────────────────────────────────────────────

/// Full staples manager reached via "See all". Add a food or combo up top,
/// then every saved staple below as tap-to-log chips (long-press to edit or
/// delete).
class StaplesManagerPage extends ConsumerWidget {
  const StaplesManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combos = ref.watch(foodCombosProvider).valueOrNull ?? const [];
    final foods =
        _sortedFoods(ref.watch(customFoodsProvider).valueOrNull ?? const []);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('My foods', style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: _BigAddButton(
                    icon: Icons.restaurant_rounded,
                    label: 'Add food',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const CustomFoodForm())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigAddButton(
                    icon: Icons.layers_rounded,
                    label: 'Add combo',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const ComboBuilderPage())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (combos.isEmpty && foods.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.restaurant_rounded,
                        size: 34, color: AppColors.textTertiary),
                    const SizedBox(height: 14),
                    Text('No saved foods yet',
                        style: AppText.sectionTitle.copyWith(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      'Save the things you eat often — a shake, your breakfast, a combo — and log them in one tap from home.',
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                  ],
                ),
              ),
            if (combos.isNotEmpty) ...[
              Text('COMBOS', style: AppText.label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: combos
                    .map((c) => _StapleChip(
                          label: c.name,
                          trailing: '${c.items.length}',
                          icon: Icons.layers_rounded,
                          highlight: true,
                          onTap: () => _logCombo(context, ref, c),
                          onLongPress: () => _comboMenu(context, ref, c),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 22),
            ],
            if (foods.isNotEmpty) ...[
              Text('FOODS', style: AppText.label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: foods
                    .map((f) => _StapleChip(
                          label: f.name,
                          trailing: '${f.caloriesPerServing}',
                          onTap: () => _logFood(context, ref, f),
                          onLongPress: () => _foodMenu(context, ref, f),
                        ))
                    .toList(),
              ),
            ],
            if (combos.isNotEmpty || foods.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Tap to log · long-press to edit or delete',
                  textAlign: TextAlign.center,
                  style: AppText.meta.copyWith(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BigAddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigAddButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.accent),
            const SizedBox(height: 8),
            Text(label,
                style: AppText.body.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _AddMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AddMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.meta.copyWith(fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.stroke,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
