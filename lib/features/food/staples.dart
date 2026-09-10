import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/custom_food.dart';
import '../../data/models/food_combo.dart';
import '../../state/providers.dart';
import '../../l10n/app_localizations.dart';
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
  final loc = AppLocalizations.of(context)!;
  try {
    final entry =
        await ref.read(nutritionRepoProvider).logCustomFood(food, servings);
    if (!context.mounted) return;
    final label = servings == 1.0
        ? food.name
        : '${_fmtServings(servings)} ${food.name}';
    _toast(context, loc.loggedLabel(label, entry.calories.toString()));
  } catch (_) {
    if (context.mounted) _toast(context, loc.couldNotLog);
  }
}

Future<void> _logCombo(
    BuildContext context, WidgetRef ref, FoodCombo combo) async {
  final loc = AppLocalizations.of(context)!;
  try {
    final r = await ref.read(nutritionRepoProvider).logCombo(combo);
    if (!context.mounted) return;
    if (r.logged == 0) {
      _toast(context, loc.nothingToLogComboRemoved);
    } else {
      _toast(context,
          loc.loggedComboItems(combo.name, r.logged.toString(), r.calories.toString()));
    }
  } catch (_) {
    if (context.mounted) _toast(context, loc.couldNotLog);
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
            Text(AppLocalizations.of(ctx)!.howMuchFood(food.name),
                style: AppText.sectionTitle),
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
  final loc = AppLocalizations.of(context)!;
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
              title: loc.newFood,
              subtitle: loc.newFoodDesc,
              onTap: () => Navigator.pop(ctx, 'food'),
            ),
            const SizedBox(height: 10),
            _AddMenuRow(
              icon: Icons.layers_rounded,
              title: loc.newCombo,
              subtitle: loc.newComboDesc,
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
  final loc = AppLocalizations.of(context)!;
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
              title: loc.editCombo,
              subtitle: loc.changeFoodsOrServings,
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            const SizedBox(height: 10),
            _AddMenuRow(
              icon: Icons.delete_outline_rounded,
              title: loc.deleteCombo,
              subtitle: loc.removeThisStack,
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
    if (context.mounted) _toast(context, loc.comboDeleted);
  }
}

Future<void> _foodMenu(
    BuildContext context, WidgetRef ref, CustomFood food) async {
  final loc = AppLocalizations.of(context)!;
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
              title: loc.logDifferentAmount,
              subtitle: '½×, 2×, 3×…',
              onTap: () => Navigator.pop(ctx, 'amount'),
            ),
            const SizedBox(height: 10),
            _AddMenuRow(
              icon: Icons.edit_rounded,
              title: loc.editFood,
              subtitle: loc.changeNameOrNutrition,
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            const SizedBox(height: 10),
            _AddMenuRow(
              icon: Icons.delete_outline_rounded,
              title: loc.deleteFood,
              subtitle: loc.removeFromStaples,
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
    if (context.mounted) _toast(context, loc.foodDeleted);
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

/// The dashboard "Quick add" shelf: your saved foods + combos as big cards
/// (same size as the old meal cards) showing full macros, each with a "+" to
/// log it as today's food. Combos come first, then foods by frequency. When
/// there's nothing saved yet it shows a single prompt card to add one.
class StaplesCardShelf extends ConsumerWidget {
  const StaplesCardShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final combos = ref.watch(foodCombosProvider).value ?? const [];
    final foods =
        _sortedFoods(ref.watch(customFoodsProvider).value ?? const []);
    final hasStaples = combos.isNotEmpty || foods.isNotEmpty;

    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.quickLog, style: AppText.sectionTitle),
        if (hasStaples)
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const StaplesManagerPage())),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(AppLocalizations.of(context)!.seeAll,
                    style: AppText.meta.copyWith(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.accent),
              ],
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 12),
        if (!hasStaples)
          _AddPromptCard(onTap: () => openStapleAddMenu(context))
        else
          const StaplesCardRow(),
      ],
    );
  }
}

/// Just the horizontal row of big food/combo cards — no header. Used both in
/// the dashboard "Quick add" shelf and below the AI field when it's focused
/// (a "recent / quick log" strip). Renders nothing when there's no staple.
class StaplesCardRow extends ConsumerWidget {
  const StaplesCardRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final combos = ref.watch(foodCombosProvider).value ?? const [];
    final foods =
        _sortedFoods(ref.watch(customFoodsProvider).value ?? const []);
    if (combos.isEmpty && foods.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: combos.length + foods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i < combos.length) {
            return _ComboBigCard(combo: combos[i], foods: foods);
          }
          return _FoodBigCard(food: foods[i - combos.length]);
        },
      ),
    );
  }
}

/// Big tap-to-log card for a single saved food. Shows calories + macros; the
/// "+" logs one serving as today's food. Long-press for amount/edit/delete.
class _FoodBigCard extends ConsumerWidget {
  final CustomFood food;
  const _FoodBigCard({required this.food});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    return _BigCard(
      title: food.name,
      subtitle: loc.perServing(food.servingDescription),
      calories: food.caloriesPerServing,
      proteinG: food.proteinGPerServing,
      carbsG: food.carbsGPerServing,
      fatG: food.fatGPerServing,
      onAdd: () => _logFood(context, ref, food),
      onLongPress: () => _foodMenu(context, ref, food),
    );
  }
}

/// Big tap-to-log card for a combo. Totals are summed from its foods; the "+"
/// logs the whole stack. Long-press to edit/delete.
class _ComboBigCard extends ConsumerWidget {
  final FoodCombo combo;
  final List<CustomFood> foods;
  const _ComboBigCard({required this.combo, required this.foods});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var kcal = 0, p = 0, c = 0, f = 0;
    for (final item in combo.items) {
      final food = foods.where((x) => x.id == item.customFoodId);
      if (food.isEmpty) continue;
      final s = item.servings;
      kcal += (food.first.caloriesPerServing * s).round();
      p += (food.first.proteinGPerServing * s).round();
      c += (food.first.carbsGPerServing * s).round();
      f += (food.first.fatGPerServing * s).round();
    }
    return _BigCard(
      title: combo.name,
      subtitle: '${combo.items.length} items',
      calories: kcal,
      proteinG: p,
      carbsG: c,
      fatG: f,
      isCombo: true,
      onAdd: () => _logCombo(context, ref, combo),
      onLongPress: () => _comboMenu(context, ref, combo),
    );
  }
}

/// Shared card body for both foods and combos.
class _BigCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final bool isCombo;
  final VoidCallback onAdd;
  final VoidCallback onLongPress;
  const _BigCard({
    required this.title,
    required this.subtitle,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.onAdd,
    required this.onLongPress,
    this.isCombo = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: 168,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isCombo
                  ? AppColors.accent.withValues(alpha: 0.35)
                  : AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title on the left, compact "+" log button pinned top-right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isCombo) ...[
                            Icon(Icons.layers_rounded,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _AddCircle(onTap: onAdd),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$calories',
                    style: AppText.sectionTitle.copyWith(
                        color: AppColors.accent, fontSize: 22)),
                const SizedBox(width: 3),
                Text(loc.kcalUnit,
                    style: AppText.meta
                        .copyWith(color: AppColors.accent, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(loc.macroLine(proteinG.toString(), carbsG.toString(), fatG.toString()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Compact circular "+" button used on cards to log the item in one tap.
class _AddCircle extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add_rounded, size: 19, color: AppColors.onAccent),
      ),
    );
  }
}

/// Shown in the shelf when the user has no saved staples yet — tapping opens
/// the add menu (food or combo).
class _AddPromptCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPromptCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 26, color: AppColors.accent),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.saveAFoodYouEatOften,
                style: AppText.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(AppLocalizations.of(context)!.logYourShakesBreakfastOrAWholeComboInOneTap,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Full-width detailed row used on the loc.seeAll manager page: name, serving,
/// calories + P/C/F, and a compact "+" to log. Long-press to edit/delete.
class _DetailCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final bool isCombo;
  final VoidCallback onAdd;
  final VoidCallback onLongPress;
  const _DetailCard({
    required this.title,
    required this.subtitle,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.onAdd,
    required this.onLongPress,
    this.isCombo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isCombo
                    ? AppColors.accent.withValues(alpha: 0.35)
                    : AppColors.stroke),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isCombo) ...[
                          Icon(Icons.layers_rounded,
                              size: 15, color: AppColors.accent),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$calories kcal · P $proteinG / C $carbsG / F $fatG',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(
                            fontSize: 12, color: AppColors.accent)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _AddCircle(onTap: onAdd),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── loc.seeAll manager page ──────────────────────────────────────────────────

/// Full staples manager reached via loc.seeAll. Add a food or combo up top,
/// then every saved staple below as tap-to-log chips (long-press to edit or
/// delete).
class StaplesManagerPage extends ConsumerWidget {
  const StaplesManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final combos = ref.watch(foodCombosProvider).value ?? const [];
    final foods =
        _sortedFoods(ref.watch(customFoodsProvider).value ?? const []);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.foodLibrary, style: AppText.sectionTitle),
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
                    label: AppLocalizations.of(context)!.addNote,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const CustomFoodForm())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigAddButton(
                    icon: Icons.layers_rounded,
                    label: AppLocalizations.of(context)!.addNote,
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
                    Text(AppLocalizations.of(context)!.noResults,
                        style: AppText.sectionTitle.copyWith(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      loc.saveStaplesDesc,
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                  ],
                ),
              ),
            if (combos.isNotEmpty) ...[
              Text(loc.combosLabel, style: AppText.label),
              const SizedBox(height: 10),
              ...combos.map((c) {
                var kcal = 0, p = 0, cb = 0, f = 0;
                for (final item in c.items) {
                  final match = foods.where((x) => x.id == item.customFoodId);
                  if (match.isEmpty) continue;
                  final s = item.servings;
                  kcal += (match.first.caloriesPerServing * s).round();
                  p += (match.first.proteinGPerServing * s).round();
                  cb += (match.first.carbsGPerServing * s).round();
                  f += (match.first.fatGPerServing * s).round();
                }
                return _DetailCard(
                  title: c.name,
                  subtitle: '${c.items.length} items',
                  calories: kcal,
                  proteinG: p,
                  carbsG: cb,
                  fatG: f,
                  isCombo: true,
                  onAdd: () => _logCombo(context, ref, c),
                  onLongPress: () => _comboMenu(context, ref, c),
                );
              }),
              const SizedBox(height: 22),
            ],
            if (foods.isNotEmpty) ...[
              Text(loc.foodsLabel, style: AppText.label),
              const SizedBox(height: 10),
              ...foods.map((f) => _DetailCard(
                    title: f.name,
                    subtitle: loc.perServing(f.servingDescription),
                    calories: f.caloriesPerServing,
                    proteinG: f.proteinGPerServing,
                    carbsG: f.carbsGPerServing,
                    fatG: f.fatGPerServing,
                    onAdd: () => _logFood(context, ref, f),
                    onLongPress: () => _foodMenu(context, ref, f),
                  )),
            ],
            if (combos.isNotEmpty || foods.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context)!.tapToLogLongPressToEditOrDelete,
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
