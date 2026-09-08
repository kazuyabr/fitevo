import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth/auth_service.dart';
import '../../state/providers.dart';
import '../../theme.dart';

enum _Mode { signIn, signUp }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _showPassword = false;

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
        content:
            Text(msg, style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pwd = _password.text;
    if (email.isEmpty || pwd.isEmpty) {
      _toast(AppLocalizations.of(context)!.enterEmailPassword);
      return;
    }
    if (_mode == _Mode.signUp && name.isEmpty) {
      _toast(AppLocalizations.of(context)!.whatShouldWeCallYou);
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (_mode == _Mode.signIn) {
        await auth.signInWithEmail(email, pwd, AppLocalizations.of(context)!);
      } else {
        await auth.signUpWithEmail(email, pwd, displayName: name, loc: AppLocalizations.of(context)!);
      }
    } catch (e) {
      if (!mounted) return;
      _toast(e is AuthException ? e.message : AppLocalizations.of(context)!.somethingWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle(AppLocalizations.of(context)!);
    } catch (e) {
      if (!mounted) return;
      _toast(e is AuthException ? e.message : AppLocalizations.of(context)!.signInFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _toast(AppLocalizations.of(context)!.enterEmailFirst);
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email, AppLocalizations.of(context)!);
      if (mounted) _toast(AppLocalizations.of(context)!.passwordResetSent(email));
    } catch (e) {
      if (!mounted) return;
      _toast(e is AuthException ? e.message : AppLocalizations.of(context)!.couldNotSendReset);
    }
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInAnonymously(AppLocalizations.of(context)!);
    } catch (e) {
      if (!mounted) return;
      _toast(e is AuthException ? e.message : AppLocalizations.of(context)!.couldNotContinue);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isSignIn = _mode == _Mode.signIn;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loc.skip,
                            style: AppText.body.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            )),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Image.asset(
                        'assets/logo/logo.png',
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        isSignIn ? loc.welcomeBack : loc.createYourAccount,
                        style: AppText.giantNumber.copyWith(
                          fontSize: 32,
                          height: 1.1,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isSignIn
                            ? loc.signInToSync
                            : loc.setUpAccount,
                        style: AppText.body.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      if (!isSignIn) ...[
                        Text(loc.yourName, style: AppText.label),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _name,
                          hint: loc.howShouldWeGreet,
                          keyboardType: TextInputType.name,
                          autofillHints: const [AutofillHints.name],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(loc.email.toUpperCase(), style: AppText.label),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _email,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.password.toUpperCase(), style: AppText.label),
                          if (isSignIn)
                            GestureDetector(
                              onTap: _busy ? null : _forgotPassword,
                              child: Text(
                                loc.forgotPassword,
                                style: AppText.label.copyWith(
                                  color: AppColors.accent,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _password,
                        hint: isSignIn ? loc.yourPassword : loc.atLeast6Chars,
                        obscure: !_showPassword,
                        autofillHints: isSignIn
                            ? const [AutofillHints.password]
                            : const [AutofillHints.newPassword],
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
                      const SizedBox(height: 22),
                      _PrimaryButton(
                        label: isSignIn ? loc.signIn : loc.createAccount,
                        busy: _busy,
                        onTap: _busy ? null : _submit,
                      ),
                      const SizedBox(height: 20),
                      const _OrDivider(),
                      const SizedBox(height: 20),
                      _GoogleButton(
                          busy: _busy, onTap: _busy ? null : _signInGoogle),
                      const SizedBox(height: 22),
                      Center(
                        child: GestureDetector(
                          onTap: _busy
                              ? null
                              : () => setState(() =>
                                  _mode = isSignIn ? _Mode.signUp : _Mode.signIn),
                          child: RichText(
                            text: TextSpan(
                              style: AppText.body
                                  .copyWith(color: AppColors.textSecondary),
                              children: [
                                TextSpan(
                                    text: isSignIn
                                        ? loc.dontHaveAccount
                                        : loc.alreadyHaveAccount),
                                TextSpan(
                                  text: isSignIn ? loc.signUp : loc.signIn,
                                  style: AppText.body.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              cursorColor: AppColors.accent,
              style: AppText.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                hintText: hint,
                hintStyle: AppText.body.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 15,
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

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.onAccent),
              )
            : Text(
                label,
                style: TextStyle(
                  color: AppColors.onAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.stroke, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(AppLocalizations.of(context)!.or,
              style: AppText.meta.copyWith(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  letterSpacing: 1)),
        ),
        Expanded(child: Divider(color: AppColors.stroke, height: 1)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;
  const _GoogleButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AppColors.accent),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    child: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: AppText.sectionTitle.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
