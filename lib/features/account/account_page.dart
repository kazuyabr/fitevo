import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth/auth_service.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../settings/settings_page.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _busy = false;
  DateTime? _lastBackup;
  bool _loadingBackupTime = true;

  @override
  void initState() {
    super.initState();
    _refreshLastBackup();
  }

  Future<void> _refreshLastBackup() async {
    try {
      final t = await ref.read(syncServiceProvider).lastBackupAt();
      if (!mounted) return;
      setState(() {
        _lastBackup = t;
        _loadingBackupTime = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBackupTime = false);
    }
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
        content:
            Text(msg, style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      await ref.read(syncServiceProvider).pushAll();
      await _refreshLastBackup();
      if (mounted) _toast(AppLocalizations.of(context)!.backupComplete);
    } catch (e) {
      if (mounted) _toast('${AppLocalizations.of(context)!.backupFailed} $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await _confirm(
      title: loc.restoreFromCloud,
      body: loc.restoreOverwrite,
      action: loc.restore,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(syncServiceProvider).pullAll();
      if (mounted) _toast(loc.restoredFromCloud);
    } catch (e) {
      if (mounted) _toast('${loc.restoreFailed} $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await _confirm(
      title: loc.signOutTitle,
      body: loc.signOutBody,
      action: loc.signOut,
    );
    if (!ok) return;
    try {
      await ref.read(authServiceProvider).signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) _toast('${loc.signOutFailed} $e');
    }
  }

  Future<void> _deleteAccount() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await _confirm(
      title: loc.deleteAccountTitle,
      body: loc.deleteAccountBody,
      action: loc.deleteEverything,
      destructive: true,
    );
    if (!ok) return;
    try {
      // Wipe local Isar first — if Firebase fails, the user can still
      // reinstall to clear everything. Reverse order leaves orphan data.
      await ref.read(dbProvider).wipeAll();
      await ref.read(authServiceProvider).deleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) {
        _toast(loc.couldNotDelete);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.sectionTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Text(body, style: AppText.body),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(AppLocalizations.of(context)!.cancel,
                        style: AppText.body
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(
                      action,
                      style: AppText.body.copyWith(
                        color: destructive
                            ? AppColors.danger
                            : AppColors.accent,
                        fontWeight: FontWeight.w700,
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
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.2, color: AppColors.accent),
          ),
        ),
      );
    }
    if (user.isAnonymous) {
      return _AnonymousUpgradeView(uid: user.uid);
    }
    final email = user.email ?? '';
    final name = user.displayName ??
        (user.email?.split('@').first ?? 'Signed in');
    final photoUrl = user.photoURL;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(loc.account, style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        shape: BoxShape.circle,
                        image: photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(photoUrl),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: photoUrl == null
                          ? Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '·',
                              style: AppText.sectionTitle
                                  .copyWith(fontSize: 20))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: AppText.sectionTitle
                                  .copyWith(fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(email, style: AppText.meta),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(AppLocalizations.of(context)!.cloudBackup1, style: AppText.label),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_done_rounded,
                            size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.lastBackup1, style: AppText.body),
                        const Spacer(),
                        Text(
                          _loadingBackupTime
                              ? AppLocalizations.of(context)!.key2
                              : _lastBackup == null
                                  ? loc.never
                                  : DateFormat('MMM d, h:mm a')
                                      .format(_lastBackup!.toLocal()),
                          style: AppText.meta.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.autoBackupOn,
                            style: AppText.meta.copyWith(
                                fontSize: 11.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryButton(
                            label: _busy ? '…' : loc.backupNow,
                            icon: Icons.cloud_upload_rounded,
                            onTap: _busy ? null : _backupNow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SecondaryButton(
                            label: loc.restore,
                            icon: Icons.cloud_download_rounded,
                            onTap: _busy ? null : _restoreFromCloud,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loc.photosOnDevice,
                      style: AppText.meta.copyWith(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(loc.preferences, style: AppText.label),
              const SizedBox(height: 10),
              _ListTile(
                icon: Icons.tune_rounded,
                label: loc.settings,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SettingsPage()),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(loc.accountSection, style: AppText.label),
              const SizedBox(height: 10),
              _ListTile(
                icon: Icons.logout_rounded,
                label: loc.signOut,
                onTap: _signOut,
              ),
              const SizedBox(height: 8),
              _ListTile(
                icon: Icons.delete_outline_rounded,
                label: loc.deleteAccount,
                destructive: true,
                onTap: _deleteAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: enabled ? AppColors.textPrimary : AppColors.textTertiary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnonymousUpgradeView extends ConsumerStatefulWidget {
  final String uid;
  const _AnonymousUpgradeView({required this.uid});

  @override
  ConsumerState<_AnonymousUpgradeView> createState() =>
      _AnonymousUpgradeViewState();
}

class _AnonymousUpgradeViewState extends ConsumerState<_AnonymousUpgradeView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  bool _createMode = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
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

  Future<void> _submitEmail() async {
    final loc = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pwd = _password.text;
    if (email.isEmpty || pwd.isEmpty) {
      _toast(loc.enterEmailPassword);
      return;
    }
    if (_createMode && name.isEmpty) {
      _toast(loc.whatShouldWeCallYou);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).linkWithEmailPassword(
            email,
            pwd,
            createAccount: _createMode,
            displayName: name,
            loc: loc,
          );
      if (mounted) _toast(loc.backupComplete);
    } catch (e) {
      if (!mounted) return;
      _toast(e is AuthException ? e.message : loc.somethingWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueGoogle() async {
    final loc = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).linkWithGoogle(loc);
      if (mounted) _toast(loc.backupComplete);
    } catch (e) {
      if (!mounted) return;
      _toast(e is AuthException ? e.message : loc.signInFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(loc.account, style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.person_outline_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.guestAccount1,
                              style: AppText.sectionTitle
                                  .copyWith(fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(AppLocalizations.of(context)!.backingUpUnderATemporaryId,
                              style: AppText.meta.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_outlined,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.noAccountHint,
                        style: AppText.body
                            .copyWith(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(loc.preferences, style: AppText.label),
              const SizedBox(height: 10),
              _ListTile(
                icon: Icons.tune_rounded,
                label: loc.settings,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SettingsPage()),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(loc.upgradeToAccount, style: AppText.label),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.addEmailGoogle,
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (_createMode) ...[
                      Text(AppLocalizations.of(context)!.yourName1, style: AppText.label),
                      const SizedBox(height: 6),
                      _MiniField(
                        controller: _name,
                        hint: AppLocalizations.of(context)!.howShouldWeGreetYou,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(loc.email.toUpperCase(), style: AppText.label),
                    const SizedBox(height: 6),
                    _MiniField(
                      controller: _email,
                      hint: AppLocalizations.of(context)!.youExampleCom,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    Text(loc.password.toUpperCase(), style: AppText.label),
                    const SizedBox(height: 6),
                    _MiniField(
                      controller: _password,
                      hint:
                          _createMode ? loc.atLeast6Chars : loc.yourPassword,
                      obscure: !_showPassword,
                      suffix: GestureDetector(
                        onTap: () =>
                            setState(() => _showPassword = !_showPassword),
                        child: Icon(
                          _showPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textTertiary,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _busy ? null : _submitEmail,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 48,
                        decoration: BoxDecoration(
                          color: _busy
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: _busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.onAccent))
                            : Text(
                                _createMode
                                    ? loc.createAccountLink
                                    : loc.signInLink,
                                style: TextStyle(
                                  color: AppColors.onAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: _busy
                            ? null
                            : () =>
                                setState(() => _createMode = !_createMode),
                        child: Text(
                          _createMode
                              ? loc.alreadyHaveAccountSign
                              : loc.newHereCreate,
                          style: AppText.meta.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: AppColors.stroke, height: 1)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(loc.or,
                              style: AppText.meta.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                  letterSpacing: 1)),
                        ),
                        Expanded(
                            child: Divider(
                                color: AppColors.stroke, height: 1)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _busy ? null : _continueGoogle,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.stroke),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              loc.continueWithGoogle,
                              style: AppText.sectionTitle.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                loc.guestDataBackedUp,
                style: AppText.meta.copyWith(
                    fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  const _MiniField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              cursorColor: AppColors.accent,
              style: AppText.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle: AppText.body.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            suffix!,
          ],
        ],
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _ListTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? AppColors.danger : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppText.body.copyWith(
                      color: color, fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
