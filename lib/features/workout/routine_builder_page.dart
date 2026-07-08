import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../data/models/routine.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import 'exercise_library_sheet.dart';

class RoutineBuilderPage extends ConsumerStatefulWidget {
  final Routine? edit;
  // Defaults every newly-added exercise inherits (chosen up front in the
  // "Build your own" sets/reps dialog). Null → sensible 3 × 8–12 fallback.
  final int? defaultSets;
  final int? defaultRepsLow;
  final int? defaultRepsHigh;
  const RoutineBuilderPage({
    super.key,
    this.edit,
    this.defaultSets,
    this.defaultRepsLow,
    this.defaultRepsHigh,
  });

  @override
  ConsumerState<RoutineBuilderPage> createState() => _RoutineBuilderPageState();
}

class _RoutineBuilderPageState extends ConsumerState<RoutineBuilderPage> {
  late final TextEditingController _name;
  late final List<RoutineDay> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.edit;
    _name = TextEditingController(text: r?.name ?? 'My Routine');
    _days = r == null
        ? <RoutineDay>[
            RoutineDay()
              ..name = 'Day 1'
              ..weekday = 0
              ..items = []
          ]
        : r.days.map(_cloneDay).toList();
  }

  RoutineDay _cloneDay(RoutineDay d) {
    final copy = RoutineDay()
      ..name = d.name
      ..weekday = d.weekday
      ..isRest = d.isRest
      ..items = d.items
          .map((i) => RoutinePlanItem()
            ..exerciseId = i.exerciseId
            ..exerciseName = i.exerciseName
            ..targetSets = i.targetSets
            ..targetRepsLow = i.targetRepsLow
            ..targetRepsHigh = i.targetRepsHigh
            ..targetWeightKg = i.targetWeightKg
            ..restSeconds = i.restSeconds
            ..notes = i.notes)
          .toList();
    return copy;
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

  void _addDay() {
    setState(() {
      _days.add(RoutineDay()
        ..name = 'Day ${_days.length + 1}'
        ..weekday = 0
        ..items = []);
    });
  }

  void _removeDay(int index) {
    setState(() => _days.removeAt(index));
  }

  Future<void> _editDayName(int index) async {
    final d = _days[index];
    final ctl = TextEditingController(text: d.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Day name',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stroke),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: ctl,
                  autofocus: true,
                  cursorColor: AppColors.accent,
                  style: AppText.body.copyWith(
                      color: AppColors.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    hintText: 'e.g. Push Day',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel',
                        style: AppText.body
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(ctx).pop(ctl.text.trim());
                    },
                    child: Text('Save',
                        style: AppText.body.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() => d.name = newName);
    }
    // Dispose after the dialog's exit transition, not during it.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.dispose());
  }

  void _pickWeekday(int dayIndex) async {
    final selected = await showModalBottomSheet<int>(
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
              Text('Assign weekday', style: AppText.sectionTitle),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var w = 0; w <= 7; w++)
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, w),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.stroke),
                        ),
                        child: Text(
                          w == 0 ? 'Any day' : _weekdayLabel(w),
                          style: AppText.body.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
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
    if (selected == null) return;
    setState(() => _days[dayIndex].weekday = selected);
  }

  Future<void> _addExerciseToDay(int dayIndex) async {
    final picked = await ExerciseLibrarySheet.show(context);
    if (picked == null || !mounted) return;
    final item = RoutinePlanItem()
      ..exerciseId = picked.exerciseId
      ..exerciseName = picked.name
      ..targetSets = widget.defaultSets ?? 3
      ..targetRepsLow = widget.defaultRepsLow ?? 8
      ..targetRepsHigh = widget.defaultRepsHigh ?? 12
      ..restSeconds = picked.restSeconds;
    // New exercises inherit the sets/reps chosen up front; tap any exercise
    // to fine-tune it. (No auto-opened editor — keeps one modal at a time.)
    setState(() => _days[dayIndex].items.add(item));
  }

  void _removeExercise(int dayIndex, int exIndex) {
    setState(() => _days[dayIndex].items.removeAt(exIndex));
  }

  Future<void> _editExercise(int dayIndex, int exIndex) async {
    final item = _days[dayIndex].items[exIndex];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _ExerciseEditSheet(item: item),
    );
    // The sheet mutates `item` on save; refresh the row's displayed numbers.
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Name your routine first.');
      return;
    }
    if (_days.every((d) => d.isRest || d.items.isEmpty)) {
      _toast('Add at least one exercise.');
      return;
    }
    // Defensively clean up day data so a malformed input can't poison
    // the Isar write. Past bug: a day with name == "" + an embedded
    // RoutinePlanItem whose exerciseId == 0 caused saveRoutine to throw,
    // which surfaced to the user as a red error screen.
    for (final d in _days) {
      if (d.name.trim().isEmpty) d.name = 'Day';
      // Items inside a rest day shouldn't be persisted.
      if (d.isRest) d.items = [];
      // Drop items that point at a missing exercise (id == 0) — these
      // sneak in if the picker crashed mid-add.
      d.items = d.items
          .where((i) => i.exerciseName.trim().isNotEmpty)
          .toList();
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(workoutRepoProvider);
      // Always build a fresh Routine instance for the put. Reusing the
      // Isar-managed `widget.edit` instance directly has caused issues
      // when its embedded `days` list is reassigned to freshly cloned
      // values — Isar can throw on the put depending on how the parent
      // was loaded. A new instance with the same id is the safe path.
      final r = Routine()
        ..id = widget.edit?.id ?? Isar.autoIncrement
        ..name = name
        ..description = widget.edit?.description
        ..isActive = widget.edit?.isActive ?? false
        ..createdAt = widget.edit?.createdAt ?? DateTime.now()
        ..days = _days;
      final saved = await repo.saveRoutine(r);
      await repo.activateRoutine(saved.id);
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).pop();
    } catch (e, st) {
      // Surface the real exception in the toast so we can debug from
      // device instead of guessing — the old generic "Could not save"
      // hid the actual failure for days.
      // ignore: avoid_print
      print('saveRoutine failed: $e\n$st');
      if (mounted) _toast('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _weekdayLabel(int w) {
    const names = [
      '—',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    if (w < 1 || w > 7) return 'Any day';
    return names[w];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(widget.edit == null ? 'New routine' : 'Edit routine',
            style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '…' : 'Save',
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('ROUTINE NAME', style: AppText.label),
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
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  hintText: 'e.g. PPL — Beginner',
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('DAYS', style: AppText.label),
            const SizedBox(height: 10),
            for (var i = 0; i < _days.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DayEditor(
                  key: ObjectKey(_days[i]),
                  day: _days[i],
                  onRename: () => _editDayName(i),
                  onWeekday: () => _pickWeekday(i),
                  onAddExercise: () => _addExerciseToDay(i),
                  onEditExercise: (j) => _editExercise(i, j),
                  onRemoveExercise: (j) => _removeExercise(i, j),
                  onReorderExercise: (oldIndex, newIndex) => setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final moved = _days[i].items.removeAt(oldIndex);
                    _days[i].items.insert(newIndex, moved);
                  }),
                  onToggleRest: () => setState(() {
                    _days[i].isRest = !_days[i].isRest;
                    if (_days[i].isRest) _days[i].items.clear();
                  }),
                  onDelete:
                      _days.length > 1 ? () => _removeDay(i) : null,
                ),
              ),
            GestureDetector(
              onTap: _addDay,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.stroke,
                      style: BorderStyle.solid,
                      width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text('Add day',
                        style: AppText.body.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
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

class _DayEditor extends StatelessWidget {
  final RoutineDay day;
  final VoidCallback onRename;
  final VoidCallback onWeekday;
  final VoidCallback onAddExercise;
  final void Function(int) onEditExercise;
  final void Function(int) onRemoveExercise;
  final void Function(int oldIndex, int newIndex) onReorderExercise;
  final VoidCallback onToggleRest;
  final VoidCallback? onDelete;
  const _DayEditor({
    super.key,
    required this.day,
    required this.onRename,
    required this.onWeekday,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onRemoveExercise,
    required this.onReorderExercise,
    required this.onToggleRest,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final weekday = day.weekday;
    final weekdayLabel =
        weekday == 0 ? 'Any day' : _RoutineBuilderPageState._weekdayLabel(weekday);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onRename,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.name,
                            style: AppText.sectionTitle.copyWith(
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: onWeekday,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 12,
                                  color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(weekdayLabel,
                                  style: AppText.meta
                                      .copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleRest,
                  icon: Icon(
                    day.isRest
                        ? Icons.self_improvement_rounded
                        : Icons.fitness_center_rounded,
                    size: 18,
                    color: day.isRest ? AppColors.water : AppColors.accent,
                  ),
                  tooltip: day.isRest ? 'Mark as training' : 'Mark as rest',
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.danger),
                  ),
              ],
            ),
          ),
          if (!day.isRest) ...[
            const Divider(height: 1),
            // Drag the handle to reorder — put the exercise you want first
            // (e.g. leg press) at the top.
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: day.items.length,
              onReorder: onReorderExercise,
              itemBuilder: (context, j) => ListTile(
                key: ObjectKey(day.items[j]),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                leading: ReorderableDragStartListener(
                  index: j,
                  child: Icon(Icons.drag_indicator_rounded,
                      size: 20, color: AppColors.textTertiary),
                ),
                title: Text(day.items[j].exerciseName,
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                subtitle: Text(
                    '${day.items[j].targetSets} × ${day.items[j].targetRepsLow}–${day.items[j].targetRepsHigh} · ${day.items[j].restSeconds}s rest',
                    style: AppText.meta.copyWith(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => onEditExercise(j),
                      icon: Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      onPressed: () => onRemoveExercise(j),
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: GestureDetector(
                onTap: onAddExercise,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text('Add exercise',
                          style: AppText.body.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  const _NumberField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: AppColors.accent,
        style:
            AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 15),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// Sets / reps / rest editor for a single routine item. A real StatefulWidget
/// so its text controllers are owned and disposed by the framework when the
/// sheet unmounts — creating/disposing them by hand around a showModalBottomSheet
/// tore controllers and focus down mid-transition and tripped a widget-tree
/// assertion. Mutates [item] in place on Save and pops `true`.
class _ExerciseEditSheet extends StatefulWidget {
  final RoutinePlanItem item;
  const _ExerciseEditSheet({required this.item});

  @override
  State<_ExerciseEditSheet> createState() => _ExerciseEditSheetState();
}

class _ExerciseEditSheetState extends State<_ExerciseEditSheet> {
  late final TextEditingController _sets =
      TextEditingController(text: widget.item.targetSets.toString());
  late final TextEditingController _low =
      TextEditingController(text: widget.item.targetRepsLow.toString());
  late final TextEditingController _high =
      TextEditingController(text: widget.item.targetRepsHigh.toString());
  late final TextEditingController _rest =
      TextEditingController(text: widget.item.restSeconds.toString());

  @override
  void dispose() {
    _sets.dispose();
    _low.dispose();
    _high.dispose();
    _rest.dispose();
    super.dispose();
  }

  void _save() {
    final it = widget.item;
    it.targetSets =
        (int.tryParse(_sets.text.trim()) ?? it.targetSets).clamp(1, 12);
    it.targetRepsLow =
        (int.tryParse(_low.text.trim()) ?? it.targetRepsLow).clamp(1, 60);
    it.targetRepsHigh = (int.tryParse(_high.text.trim()) ?? it.targetRepsHigh)
        .clamp(it.targetRepsLow, 100);
    it.restSeconds =
        (int.tryParse(_rest.text.trim()) ?? it.restSeconds).clamp(0, 600);
    // Drop focus/keyboard before popping so the focus tree settles before
    // this subtree is torn down.
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
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
              const SizedBox(height: 14),
              Text(widget.item.exerciseName,
                  style: AppText.sectionTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 14),
              Text('SETS', style: AppText.label),
              const SizedBox(height: 6),
              _NumberField(controller: _sets),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REPS (LOW)', style: AppText.label),
                        const SizedBox(height: 6),
                        _NumberField(controller: _low),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REPS (HIGH)', style: AppText.label),
                        const SizedBox(height: 6),
                        _NumberField(controller: _high),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('REST (SECONDS)', style: AppText.label),
              const SizedBox(height: 6),
              _NumberField(controller: _rest),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _save,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text('Save',
                      style: TextStyle(
                        color: AppColors.onAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

