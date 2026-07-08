import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/custom_food.dart';
import '../../data/models/food_combo.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import 'custom_foods_page.dart';

/// Build or edit a "my usual" combo — a bundle of saved staples logged in one
/// tap. Pick foods, set how many servings of each, name it, save.
class ComboBuilderPage extends ConsumerStatefulWidget {
  final FoodCombo? initial;
  const ComboBuilderPage({super.key, this.initial});

  @override
  ConsumerState<ComboBuilderPage> createState() => _ComboBuilderPageState();
}

class _ComboBuilderPageState extends ConsumerState<ComboBuilderPage> {
  late final TextEditingController _name;
  // customFoodId -> servings. Insertion order preserved for a stable list.
  final Map<int, double> _selected = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    for (final item in widget.initial?.items ?? const <ComboItem>[]) {
      _selected[item.customFoodId] = item.servings;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(msg,
            style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Name your combo — e.g. "Morning stack".');
      return;
    }
    if (_selected.isEmpty) {
      _toast('Add at least one food.');
      return;
    }
    setState(() => _busy = true);
    try {
      final combo = widget.initial ?? FoodCombo();
      combo
        ..name = name
        ..items = _selected.entries
            .map((e) => ComboItem()
              ..customFoodId = e.key
              ..servings = e.value)
            .toList();
      await ref.read(nutritionRepoProvider).saveCombo(combo);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _toast('Could not save.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(double s) =>
      s == s.roundToDouble() ? '${s.toInt()}×' : '${s.toStringAsFixed(1)}×';

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(customFoodsProvider).valueOrNull ?? const [];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(widget.initial == null ? 'New combo' : 'Edit combo',
            style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(widget.initial == null ? 'Save' : 'Update',
                style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
        ],
      ),
      body: SafeArea(
        child: foods.isEmpty
            ? _NoFoodsYet(onAdd: () {
                Navigator.of(context).push(MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const CustomFoodForm()));
              })
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Text('NAME', style: AppText.label),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _name,
                      cursorColor: AppColors.accent,
                      style: AppText.body.copyWith(
                          color: AppColors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        hintText: 'Morning stack',
                        hintStyle: AppText.body.copyWith(
                            color: AppColors.textTertiary, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('FOODS IN THIS COMBO', style: AppText.label),
                      Text('${_selected.length} selected',
                          style: AppText.meta
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...foods.map((f) => _FoodRow(
                        food: f,
                        servings: _selected[f.id],
                        fmt: _fmt,
                        onToggle: () => setState(() {
                          if (_selected.containsKey(f.id)) {
                            _selected.remove(f.id);
                          } else {
                            _selected[f.id] = 1.0;
                          }
                        }),
                        onStep: (delta) => setState(() {
                          final cur = _selected[f.id] ?? 1.0;
                          final next =
                              (cur + delta).clamp(0.5, 20.0).toDouble();
                          _selected[f.id] = next;
                        }),
                      )),
                ],
              ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final CustomFood food;
  final double? servings;
  final VoidCallback onToggle;
  final void Function(double delta) onStep;
  final String Function(double) fmt;
  const _FoodRow({
    required this.food,
    required this.servings,
    required this.onToggle,
    required this.onStep,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final selected = servings != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.stroke),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? AppColors.accent : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name,
                        style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${food.caloriesPerServing} kcal · per ${food.servingDescription}',
                        style: AppText.meta.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            if (selected) ...[
              _StepBtn(icon: Icons.remove_rounded, onTap: () => onStep(-0.5)),
              SizedBox(
                width: 40,
                child: Text(fmt(servings!),
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800)),
              ),
              _StepBtn(icon: Icons.add_rounded, onTap: () => onStep(0.5)),
            ],
          ],
        ),
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
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

class _NoFoodsYet extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoFoodsYet({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_rounded, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('Save some foods first',
                style: AppText.sectionTitle.copyWith(fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              'A combo bundles staples you already saved. Add a food or two, then come back to stack them.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Add a food',
                    style: TextStyle(
                        color: AppColors.onAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
