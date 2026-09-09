import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/settings/app_settings.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../food/custom_foods_page.dart';
import 'api_keys_page.dart';
import 'health_sync_page.dart';
import 'profile_edit_page.dart';
import 'reminders_page.dart';
import '../../l10n/app_localizations.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _exporting = false;
  bool _resetting = false;
  bool _resettingTraining = false;

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

  Future<void> _exportData() async {
    final loc = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      final path =
          await ref.read(dataExportServiceProvider).exportToFile();
      if (!mounted) return;
      // Hand off to the system share sheet — user picks Drive, Files,
      // Gmail, WhatsApp, anywhere they want the backup to land.
      final result = await Share.shareXFiles(
        [XFile(path)],
        subject: loc.fitevoBackup,
        text: loc.fitevoBackupRestore,
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        _toast(loc.backupShared);
      }
    } catch (_) {
      if (mounted) _toast(loc.exportFailed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _resetTrainingData() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.resetTraining,
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                loc.wipesEvery,
                style: AppText.body,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(loc.cancel,
                        style: AppText.body.copyWith(
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(loc.reset,
                        style: AppText.body.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _resettingTraining = true);
    try {
      await ref.read(dataExportServiceProvider).clearTrainingData();
      if (!mounted) return;
      _toast(loc.resetTraining);
    } catch (_) {
      if (mounted) _toast(loc.resetFailed);
    } finally {
      if (mounted) setState(() => _resettingTraining = false);
    }
  }

  Future<void> _resetEverything() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.wipeEverything,
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                loc.localFood,
                style: AppText.body,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(loc.cancel,
                        style: AppText.body.copyWith(
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(loc.wipe,
                        style: AppText.body.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _resetting = true);
    try {
      await ref.read(dataExportServiceProvider).clearAll();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      if (mounted) _toast(loc.resetFailed);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final mode = ref.watch(themeModeProvider);
    final units = ref.watch(unitsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(loc.settings, style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.profileTargets, style: AppText.label),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileEditPage()),
                ),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.profileGoalAndTargets,
                                style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            Text(AppLocalizations.of(context)!.overrideAnyAutoComputedTarget,
                                style:
                                    AppText.meta.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.healthSync, style: AppText.label),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const HealthSyncPage()),
                ),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monitor_heart_rounded,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.manualBandSync,
                                style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                loc.healthSyncDesc,
                                style: AppText.meta.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(loc.reminders, style: AppText.label),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RemindersPage()),
                ),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_rounded,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(loc.waterMealReminders,
                            style: AppText.body.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(loc.apiKeys, style: AppText.label),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ApiKeysPage()),
                ),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.key_rounded,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.apiKeys,
                                style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            Text(loc.apiKeysDescription,
                                style: AppText.meta.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(loc.units, style: AppText.label),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _UnitOption(
                        label: AppLocalizations.of(context)!.metric,
                        sub: 'kg · cm · L',
                        selected: units == UnitSystem.metric,
                        onTap: () async {
                          await ref
                              .read(appSettingsProvider)
                              .setUnits(UnitSystem.metric);
                          ref.read(unitsProvider.notifier).state =
                              UnitSystem.metric;
                        },
                      ),
                    ),
                    Expanded(
                      child: _UnitOption(
                        label: AppLocalizations.of(context)!.imperial,
                        sub: 'lb · ft / in · fl oz',
                        selected: units == UnitSystem.imperial,
                        onTap: () async {
                          await ref
                              .read(appSettingsProvider)
                              .setUnits(UnitSystem.imperial);
                          ref.read(unitsProvider.notifier).state =
                              UnitSystem.imperial;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.appearance, style: AppText.label),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeOption(
                        label: AppLocalizations.of(context)!.dark,
                        icon: Icons.dark_mode_rounded,
                        selected: mode == ThemeMode.dark,
                        onTap: () async {
                          final r = ref;
                          await r
                              .read(appSettingsProvider)
                              .setThemeMode(ThemeMode.dark);
                          r.read(themeModeProvider.notifier).state =
                              ThemeMode.dark;
                        },
                      ),
                    ),
                    Expanded(
                      child: _ModeOption(
                        label: AppLocalizations.of(context)!.light,
                        icon: Icons.light_mode_rounded,
                        selected: mode == ThemeMode.light,
                        onTap: () async {
                          final r = ref;
                          await r
                              .read(appSettingsProvider)
                              .setThemeMode(ThemeMode.light);
                          r.read(themeModeProvider.notifier).state =
                              ThemeMode.light;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.foodLibrary1, style: AppText.label),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CustomFoodsPage()),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant_rounded,
                          size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.customFoods,
                                style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(AppLocalizations.of(context)!.saveMealsYouLogOften,
                                style:
                                    AppText.meta.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.data, style: AppText.label),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _exporting ? null : _exportData,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.file_download_outlined,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _exporting
                              ? loc.exporting
                              : loc.exportMyData,
                          style: AppText.body.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _resettingTraining ? null : _resetTrainingData,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.replay_rounded,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resettingTraining
                                  ? loc.clearing
                                  : loc.resetTraining,
                              style: AppText.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                                loc.wipesEvery,
                                style: AppText.meta.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _resetting ? null : _resetEverything,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.restart_alt_rounded,
                          size: 18, color: AppColors.danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _resetting ? loc.wiping : loc.resetEverything,
                          style: AppText.body.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
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

class _UnitOption extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _UnitOption({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                  color: selected ? AppColors.onAccent : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.2,
                )),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                  color: selected
                      ? AppColors.onAccent.withValues(alpha: 0.7)
                      : AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                )),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.onAccent : AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.onAccent : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
