import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import 'ai_provider_page.dart';

class ApiKeysPage extends ConsumerStatefulWidget {
  const ApiKeysPage({super.key});

  @override
  ConsumerState<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends ConsumerState<ApiKeysPage> {
  late final TextEditingController _geminiCtrl;
  late final TextEditingController _groqCtrl;
  late final TextEditingController _usdaCtrl;
  late final TextEditingController _proxyCtrl;
  bool _obscureGemini = true;
  bool _obscureGroq = true;
  bool _obscureUsda = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _geminiCtrl = TextEditingController(text: settings.geminiApiKey);
    _groqCtrl = TextEditingController(text: settings.groqApiKey);
    _usdaCtrl = TextEditingController(text: settings.usdaApiKey);
    _proxyCtrl = TextEditingController(text: settings.aiProxyUrl);
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _groqCtrl.dispose();
    _usdaCtrl.dispose();
    _proxyCtrl.dispose();
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

  Future<void> _save() async {
    final settings = ref.read(appSettingsProvider);
    await settings.setGeminiApiKey(_geminiCtrl.text.trim());
    await settings.setGroqApiKey(_groqCtrl.text.trim());
    await settings.setUsdaApiKey(_usdaCtrl.text.trim());
    await settings.setAiProxyUrl(_proxyCtrl.text.trim());
    // Rebuild cached services so new keys take effect without a restart.
    ref.invalidate(aiServiceProvider);
    ref.invalidate(usdaServiceProvider);
    // The proxy URL may have changed — rebuild and re-pull the training
    // package so the trainer persona follows the new proxy.
    ref.invalidate(trainingServiceProvider);
    unawaited(ref.read(trainingServiceProvider).refresh(force: true));
    if (mounted) _toast(AppLocalizations.of(context)!.save);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(loc.settings, style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(loc.save,
                style: AppText.body.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.apiKeysDescription,
                        style: AppText.body
                            .copyWith(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(loc.aiProviderTitle, style: AppText.label),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final s = ref.read(appSettingsProvider);
                final hasCustom = s.aiProviderName.isNotEmpty;
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AiProviderPage()),
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
                        Icon(Icons.auto_awesome_rounded,
                            size: 18, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasCustom
                                    ? '${s.aiProviderName} · ${s.aiProviderModel}'
                                    : loc.aiProviderTitle,
                                style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                loc.aiProviderDesc,
                                style: AppText.meta.copyWith(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              Text(loc.aiProxy, style: AppText.label),
              const SizedBox(height: 6),
              _ApiKeyField(
                controller: _proxyCtrl,
                hint: 'https://your-proxy.example.com',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              Text('Groq', style: AppText.label),
              const SizedBox(height: 6),
              _ApiKeyField(
                controller: _groqCtrl,
                hint: 'gsk_...',
                obscure: _obscureGroq,
                onToggle: () =>
                    setState(() => _obscureGroq = !_obscureGroq),
              ),
              const SizedBox(height: 20),
              Text('Gemini', style: AppText.label),
              const SizedBox(height: 6),
              _ApiKeyField(
                controller: _geminiCtrl,
                hint: 'AIza...',
                obscure: _obscureGemini,
                onToggle: () =>
                    setState(() => _obscureGemini = !_obscureGemini),
              ),
              const SizedBox(height: 20),
              Text('USDA', style: AppText.label),
              const SizedBox(height: 6),
              _ApiKeyField(
                controller: _usdaCtrl,
                hint: 'DEMO_KEY or your key',
                obscure: _obscureUsda,
                onToggle: () =>
                    setState(() => _obscureUsda = !_obscureUsda),
              ),
              const SizedBox(height: 24),
              Text(loc.aiPriority, style: AppText.label),
              const SizedBox(height: 8),
              Text(
                loc.aiPriorityDesc,
                style: AppText.body.copyWith(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiKeyField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final VoidCallback? onToggle;

  const _ApiKeyField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onToggle,
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
          if (onToggle != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.textTertiary,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
