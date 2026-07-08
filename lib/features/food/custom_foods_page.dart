import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/custom_food.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/skeleton.dart';

class CustomFoodsPage extends ConsumerWidget {
  const CustomFoodsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(customFoodsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('My foods', style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: () => _openForm(context),
            icon: Icon(Icons.add_rounded, color: AppColors.accent),
          ),
        ],
      ),
      body: SafeArea(
        // Skeleton rows shaped like the saved-food cards while loading.
        child: foodsAsync.when(
          loading: () => ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, _) => const SkeletonRow(height: 72),
          ),
          error: (e, _) => Center(
            child: Text('Could not load foods.', style: AppText.body),
          ),
          data: (foods) {
            if (foods.isEmpty) return _Empty(onCreate: () => _openForm(context));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: foods.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _FoodCard(food: foods[i]),
            );
          },
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {CustomFood? edit}) {
    Navigator.of(context).push(
      MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CustomFoodForm(initial: edit)),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onCreate;
  const _Empty({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.restaurant_rounded,
                  size: 28, color: AppColors.accent),
            ),
            const SizedBox(height: 18),
            Text('No custom foods yet',
                style: AppText.sectionTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              'Save the meals you eat often — home-cooked dishes, shakes, anything the AI doesn\'t quite nail.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.onAccent, size: 18),
                    const SizedBox(width: 6),
                    Text('Create one',
                        style: TextStyle(
                          color: AppColors.onAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodCard extends ConsumerStatefulWidget {
  final CustomFood food;
  const _FoodCard({required this.food});

  @override
  ConsumerState<_FoodCard> createState() => _FoodCardState();
}

class _FoodCardState extends ConsumerState<_FoodCard> {
  bool _logging = false;

  Future<void> _logOne() async {
    setState(() => _logging = true);
    try {
      final entry = await ref
          .read(nutritionRepoProvider)
          .logCustomFood(widget.food, 1.0);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text('Logged · ${entry.calories} kcal',
              style: AppText.body.copyWith(color: AppColors.textPrimary)),
        ));
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _openMenu() async {
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
              Text(widget.food.name, style: AppText.sectionTitle),
              const SizedBox(height: 18),
              _SheetAction(
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              const SizedBox(height: 8),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                destructive: true,
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'edit') {
      Navigator.of(context).push(
        MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CustomFoodForm(initial: widget.food)),
      );
    } else if (choice == 'delete') {
      await ref
          .read(nutritionRepoProvider)
          .deleteCustomFood(widget.food.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    return GestureDetector(
      onLongPress: _openMenu,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name,
                      style: AppText.sectionTitle.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    '${f.caloriesPerServing} kcal · ${f.proteinGPerServing}P / ${f.carbsGPerServing}C / ${f.fatGPerServing}F · per ${f.servingDescription}',
                    style: AppText.meta.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _logging ? null : _logOne,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _logging
                      ? AppColors.accent.withValues(alpha: 0.5)
                      : AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _logging
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onAccent))
                    : Text(
                        'Log',
                        style: TextStyle(
                          color: AppColors.onAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _openMenu,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(Icons.more_vert_rounded,
                    size: 18, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.danger
        : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppText.body.copyWith(
                      color: color, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomFoodForm extends ConsumerStatefulWidget {
  final CustomFood? initial;
  const CustomFoodForm({super.key, this.initial});

  @override
  ConsumerState<CustomFoodForm> createState() => _CustomFoodFormState();
}

class _CustomFoodFormState extends ConsumerState<CustomFoodForm> {
  late final TextEditingController _name;
  late final TextEditingController _servingDesc;
  late final TextEditingController _servingSize;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _fiber;
  late final TextEditingController _sodium;
  late final TextEditingController _ingredients;
  late final TextEditingController _describe;
  bool _busy = false;
  bool _estimating = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _describe = TextEditingController();
    _name = TextEditingController(text: i?.name ?? '');
    _servingDesc =
        TextEditingController(text: i?.servingDescription ?? '1 serving');
    _servingSize = TextEditingController(
        text: i == null ? '100' : i.servingSizeG.round().toString());
    _kcal =
        TextEditingController(text: (i?.caloriesPerServing ?? 0).toString());
    _protein =
        TextEditingController(text: (i?.proteinGPerServing ?? 0).toString());
    _carbs =
        TextEditingController(text: (i?.carbsGPerServing ?? 0).toString());
    _fat = TextEditingController(text: (i?.fatGPerServing ?? 0).toString());
    _fiber =
        TextEditingController(text: (i?.fiberGPerServing ?? 0).toString());
    _sodium =
        TextEditingController(text: (i?.sodiumMgPerServing ?? 0).toString());
    _ingredients = TextEditingController(text: i?.ingredients ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _servingDesc.dispose();
    _servingSize.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _fiber.dispose();
    _sodium.dispose();
    _ingredients.dispose();
    _describe.dispose();
    super.dispose();
  }

  /// Ask the AI to fill the nutrition fields from the plain-language
  /// description. Honors any macros the user stated in the text; estimates
  /// the rest. Only overwrites a field when the AI has a value for it, so a
  /// number the user already typed isn't wiped by a zero.
  Future<void> _autoFill() async {
    final desc = _describe.text.trim();
    if (desc.isEmpty) {
      _toast('Describe the food first — e.g. "1 scoop whey with 150ml milk".');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _estimating = true);
    try {
      final est =
          await ref.read(foodLoggerProvider).estimateCustomFood(desc);
      if (!mounted) return;
      if (est == null) {
        _toast('Could not estimate — enter the numbers manually.');
        return;
      }
      if (_name.text.trim().isEmpty && est.name.isNotEmpty) {
        _name.text = est.name;
      }
      // Fill each macro only when the AI returned a value, so a figure the
      // user typed by hand isn't overwritten with a zero.
      if (est.calories > 0) _kcal.text = est.calories.toString();
      if (est.proteinG > 0) _protein.text = est.proteinG.toString();
      if (est.carbsG > 0) _carbs.text = est.carbsG.toString();
      if (est.fatG > 0) _fat.text = est.fatG.toString();
      if (est.fiberG > 0) _fiber.text = est.fiberG.toString();
      if (est.sodiumMg > 0) _sodium.text = est.sodiumMg.toString();
      _toast('Filled in — check the numbers and tweak if needed.');
    } catch (e) {
      if (mounted) _toast('Could not estimate right now.');
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        content: Text(msg,
            style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
  }

  int _i(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  double _d(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0.0;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Give your food a name.');
      return;
    }
    setState(() => _busy = true);
    try {
      final food = widget.initial ?? CustomFood();
      food
        ..name = name
        ..servingDescription = _servingDesc.text.trim().isEmpty
            ? '1 serving'
            : _servingDesc.text.trim()
        ..servingSizeG = _d(_servingSize)
        ..caloriesPerServing = _i(_kcal)
        ..proteinGPerServing = _i(_protein)
        ..carbsGPerServing = _i(_carbs)
        ..fatGPerServing = _i(_fat)
        ..fiberGPerServing = _i(_fiber)
        ..sodiumMgPerServing = _i(_sodium)
        ..ingredients = _ingredients.text.trim().isEmpty
            ? null
            : _ingredients.text.trim();
      await ref.read(nutritionRepoProvider).saveCustomFood(food);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _toast('Could not save.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(widget.initial == null ? 'New food' : 'Edit food',
            style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(
              widget.initial == null ? 'Save' : 'Update',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI auto-fill: describe the food in plain words, let the model
              // fill the macros. State what you know ("24g protein"), estimate
              // the rest. Everything stays editable below.
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 15, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text('DESCRIBE IT',
                            style: AppText.label
                                .copyWith(color: AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _FormField(
                      controller: _describe,
                      hint:
                          '1 scoop whey + 150ml milk · or "4 eggs" · add any macros you know',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _estimating ? null : _autoFill,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _estimating
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: _estimating
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onAccent),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome_rounded,
                                      size: 16, color: AppColors.onAccent),
                                  const SizedBox(width: 6),
                                  Text('Auto-fill with AI',
                                      style: TextStyle(
                                        color: AppColors.onAccent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      )),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('NAME', style: AppText.label),
              const SizedBox(height: 8),
              _FormField(controller: _name, hint: 'e.g. Mom\'s dal'),
              const SizedBox(height: 18),
              Text('SERVING', style: AppText.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _FormField(
                      controller: _servingDesc,
                      hint: '1 bowl',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FormField(
                      controller: _servingSize,
                      hint: 'grams',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('NUTRITION (PER SERVING)', style: AppText.label),
              const SizedBox(height: 8),
              _FormField(
                controller: _kcal,
                hint: 'Calories',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _protein,
                      hint: 'Protein (g)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FormField(
                      controller: _carbs,
                      hint: 'Carbs (g)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FormField(
                      controller: _fat,
                      hint: 'Fat (g)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _fiber,
                      hint: 'Fiber (g)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FormField(
                      controller: _sodium,
                      hint: 'Sodium (mg)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('NOTES (OPTIONAL)', style: AppText.label),
              const SizedBox(height: 8),
              _FormField(
                controller: _ingredients,
                hint: 'Ingredients, recipe link, etc.',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  const _FormField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        cursorColor: AppColors.accent,
        style: AppText.body
            .copyWith(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: hint,
          hintStyle:
              AppText.body.copyWith(color: AppColors.textTertiary, fontSize: 15),
        ),
      ),
    );
  }
}
