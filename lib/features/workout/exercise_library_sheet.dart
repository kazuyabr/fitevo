import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../services/workout/exercise_image_service.dart';
import '../../state/providers.dart';
import '../../theme.dart';

/// What the user chose from the library — always resolves to a real saved
/// [Exercise] id (created on the fly for catalog / custom picks).
class PickedLibraryExercise {
  final String name;
  final int exerciseId;
  final int restSeconds;
  const PickedLibraryExercise({
    required this.name,
    required this.exerciseId,
    this.restSeconds = 90,
  });
}

/// A photo-first exercise browser backed by the ~800-exercise free-exercise-db
/// catalog. Browse by muscle group, recognise a machine by its picture even
/// when you don't know its name, or add a custom one by hand. Fetches the
/// catalog on demand (needs network); falls back to custom-by-name offline.
class ExerciseLibrarySheet extends ConsumerStatefulWidget {
  const ExerciseLibrarySheet({super.key});

  static Future<PickedLibraryExercise?> show(BuildContext context) {
    return showModalBottomSheet<PickedLibraryExercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ExerciseLibrarySheet(),
    );
  }

  @override
  ConsumerState<ExerciseLibrarySheet> createState() =>
      _ExerciseLibrarySheetState();
}

class _ExerciseLibrarySheetState extends ConsumerState<ExerciseLibrarySheet> {
  final _search = TextEditingController();
  final _custom = TextEditingController();
  String _query = '';
  MuscleGroup? _filter;
  bool _customMode = false;

  List<CatalogExercise>? _catalog; // null = still loading
  bool _busy = false;

  static const _muscles = [
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.shoulders,
    MuscleGroup.biceps,
    MuscleGroup.triceps,
    MuscleGroup.core,
    MuscleGroup.quads,
    MuscleGroup.hamstrings,
    MuscleGroup.glutes,
    MuscleGroup.calves,
    MuscleGroup.cardio,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cat = await ref.read(exerciseImageServiceProvider).catalog();
      if (!mounted) return;
      setState(() => _catalog = cat);
    } catch (_) {
      if (mounted) setState(() => _catalog = const []);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _custom.dispose();
    super.dispose();
  }

  List<CatalogExercise> _filtered() {
    final all = _catalog ?? const [];
    final words = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return all.where((e) {
      if (_filter != null && !e.muscles.contains(_filter)) return false;
      if (words.isEmpty) return true;
      // Forgiving match over name + equipment + muscles, so "pull down back"
      // finds "Lat Pulldown" even without the exact name.
      final hay = '${e.name} ${e.equipment.name} '
              '${e.muscles.map((m) => m.name).join(' ')}'
          .toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  Future<void> _pickCatalog(CatalogExercise e) async {
    if (_busy) return;
    setState(() => _busy = true);
    final id = await ref.read(exerciseRepoProvider).upsertByName(
          e.name,
          newExercise: () => Exercise()
            ..name = e.name
            ..muscleGroups = e.muscles
            ..equipment = e.equipment
            ..isSeeded = false,
        );
    if (!mounted) return;
    Navigator.of(context).pop(
        PickedLibraryExercise(name: e.name, exerciseId: id));
  }

  Future<void> _pickCustom() async {
    final name = _custom.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final id = await ref.read(exerciseRepoProvider).upsertByName(
          name,
          newExercise: () => Exercise()
            ..name = name
            ..isSeeded = false,
        );
    if (!mounted) return;
    Navigator.of(context).pop(PickedLibraryExercise(name: name, exerciseId: id));
  }

  /// Snap (or pick) a photo of the machine; the AI names it and we filter the
  /// catalog to its best guess so the user confirms by photo. Any failure
  /// just leaves them in the browser — never a dead end.
  Future<void> _identifyByPhoto() async {
    if (_busy) return;
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
    } catch (_) {
      // No camera (e.g. emulator) — fall back to the gallery.
      try {
        file = await picker.pickImage(
            source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
      } catch (_) {}
    }
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      final hint = _query.trim().isEmpty ? null : _query.trim();
      final names = await ref
          .read(aiServiceProvider)
          .identifyExercise(imageBytes: bytes, hint: hint);
      if (!mounted) return;
      if (names.isEmpty) {
        _snack("Couldn't identify it — browse by muscle or type a name.");
      } else {
        setState(() {
          _filter = null;
          _search.text = names.first;
          _query = names.first;
        });
        _snack('Best guess: ${names.take(3).join(', ')}');
      }
    } catch (_) {
      if (mounted) _snack('Identify failed — browse or type a name.');
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
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: h * 0.82,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(_customMode ? 'Add by name' : 'Exercise library',
                          style: AppText.sectionTitle),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _customMode = !_customMode),
                      child: Row(
                        children: [
                          Icon(_customMode ? Icons.grid_view_rounded : Icons.add_rounded,
                              size: 15, color: AppColors.accent),
                          const SizedBox(width: 3),
                          Text(_customMode ? 'Browse' : 'Custom',
                              style: AppText.label.copyWith(
                                  color: AppColors.accent, letterSpacing: 0.4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_customMode)
                  _buildCustom()
                else
                  Expanded(child: _buildBrowse()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustom() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Can't find it? Add it by name — it still tracks and logs.",
            style: AppText.meta.copyWith(fontSize: 12)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stroke),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _custom,
            autofocus: true,
            cursorColor: AppColors.accent,
            textCapitalization: TextCapitalization.words,
            style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
              hintText: 'Exercise name',
            ),
            onSubmitted: (_) => _pickCustom(),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickCustom,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('Add this exercise',
                style: TextStyle(
                    color: AppColors.onAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _buildBrowse() {
    if (_catalog == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent),
            const SizedBox(height: 14),
            Text('Loading the exercise library…',
                style: AppText.meta.copyWith(fontSize: 12)),
          ],
        ),
      );
    }
    if (_catalog!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Library needs internet to load its photos.\n'
                  'Tap “Custom” to add an exercise by name.',
                  textAlign: TextAlign.center,
                  style: AppText.meta.copyWith(fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final results = _filtered();
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stroke),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _search,
                  cursorColor: AppColors.accent,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    hintText: 'Search or describe it…',
                  ),
                ),
              ),
              GestureDetector(
                onTap: _busy ? null : _identifyByPhoto,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 2),
                  child: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : Icon(Icons.photo_camera_rounded,
                          size: 20, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('All', _filter == null, () => setState(() => _filter = null)),
              for (final g in _muscles)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _chip(_label(g), _filter == g,
                      () => setState(() => _filter = _filter == g ? null : g)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: results.isEmpty
              ? Center(child: Text('No matches.', style: AppText.body))
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _row(results[i]),
                ),
        ),
      ],
    );
  }

  Widget _row(CatalogExercise e) {
    return GestureDetector(
      onTap: () => _pickCatalog(e),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 60,
                height: 60,
                color: AppColors.surface,
                child: Image.network(
                  e.imageUrls.first,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, prog) => prog == null
                      ? child
                      : Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.textTertiary)),
                        ),
                  errorBuilder: (_, _, _) => Icon(Icons.fitness_center_rounded,
                      size: 22, color: AppColors.textTertiary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: AppText.body.copyWith(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [
                      e.muscles.isNotEmpty ? _label(e.muscles.first) : null,
                      _equipLabel(e.equipment),
                    ].whereType<String>().join(' · '),
                    style: AppText.meta.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded,
                size: 22, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.stroke),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? AppColors.onAccent : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            )),
      ),
    );
  }

  String _label(MuscleGroup g) {
    final n = g.name;
    return n[0].toUpperCase() + n.substring(1);
  }

  String _equipLabel(Equipment e) {
    final n = e.name;
    return n[0].toUpperCase() + n.substring(1);
  }
}
