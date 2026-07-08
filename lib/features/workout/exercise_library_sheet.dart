import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
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

  /// Show a bigger preview (photos + how-to) before committing to add.
  Future<void> _showDetail(CatalogExercise e) async {
    final add = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CatalogDetailSheet(exercise: e),
    );
    if (add == true && mounted) await _pickCatalog(e);
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
            ..formCues = e.instructions
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
      onTap: () => _showDetail(e),
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
                child: CachedNetworkImage(
                  imageUrl: e.imageUrls.first,
                  fit: BoxFit.cover,
                  // Disk-cached + decoded to thumbnail size so re-scrolls are
                  // instant and it survives a slow first load.
                  memCacheWidth: 180,
                  memCacheHeight: 180,
                  fadeInDuration: const Duration(milliseconds: 120),
                  placeholder: (_, _) => const Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => Icon(Icons.fitness_center_rounded,
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
            GestureDetector(
              onTap: () => _pickCatalog(e),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.add_circle_outline_rounded,
                    size: 24, color: AppColors.accent),
              ),
            ),
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

/// Bigger preview of a catalog exercise — swipeable photos, muscles /
/// equipment, and the how-to steps — with an "Add" button. Pops `true` to
/// add, `null`/false to back out.
class _CatalogDetailSheet extends StatelessWidget {
  final CatalogExercise exercise;
  const _CatalogDetailSheet({required this.exercise});

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final tags = [
      ...e.muscles.map((m) => _cap(m.name)),
      _cap(e.equipment.name),
    ].join('  ·  ');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              const SizedBox(height: 10),
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
              const SizedBox(height: 12),
              if (e.imageUrls.isNotEmpty)
                SizedBox(
                  height: 230,
                  child: PageView(
                    children: [
                      for (final url in e.imageUrls)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              color: AppColors.surfaceHigh,
                              width: double.infinity,
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                memCacheWidth: 720,
                                placeholder: (_, _) => const Center(
                                    child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))),
                                errorWidget: (_, _, _) => Center(
                                    child: Icon(Icons.fitness_center_rounded,
                                        size: 40,
                                        color: AppColors.textTertiary)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name,
                          style: AppText.sectionTitle.copyWith(fontSize: 20)),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(tags, style: AppText.meta.copyWith(fontSize: 12)),
                      ],
                      if (e.instructions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('HOW TO DO IT', style: AppText.label),
                        const SizedBox(height: 10),
                        for (var i = 0; i < e.instructions.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i + 1}.',
                                    style: AppText.body.copyWith(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(e.instructions[i],
                                      style: AppText.body.copyWith(
                                          fontSize: 13.5, height: 1.45)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Add this exercise',
                        style: AppText.body.copyWith(
                            color: AppColors.onAccent,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
