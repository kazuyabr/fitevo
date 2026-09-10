import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/ai/model_catalog.dart';
import '../../state/providers.dart';
import '../../theme.dart';

/// Lets the user run AI on their own account: pick a provider from the
/// models.dev catalog, choose a model and paste an API key. The trainer
/// persona/context still comes from the app (proxy training package).
class AiProviderPage extends ConsumerStatefulWidget {
  const AiProviderPage({super.key});

  @override
  ConsumerState<AiProviderPage> createState() => _AiProviderPageState();
}

class _AiProviderPageState extends ConsumerState<AiProviderPage> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _proxyCtrl;

  String _providerId = '';
  String _providerName = '';
  String _model = '';

  List<CatalogProvider>? _catalog;
  bool _loading = true;
  String? _error;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _providerId = s.aiProviderId;
    _providerName = s.aiProviderName;
    _model = s.aiProviderModel;
    _keyCtrl = TextEditingController(text: s.aiProviderApiKey);
    _baseUrlCtrl = TextEditingController(text: s.aiProviderBaseUrl);
    _proxyCtrl = TextEditingController(text: s.aiProxyUrl);
    _loadCatalog();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _proxyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(modelCatalogServiceProvider).load();
      if (!mounted) return;
      setState(() {
        _catalog = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.catalogLoadFailed;
      });
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

  CatalogProvider? get _selectedProvider {
    final list = _catalog;
    if (list == null) return null;
    for (final p in list) {
      if (p.id == _providerId) return p;
    }
    return null;
  }

  CatalogModel? get _selectedModel {
    final provider = _selectedProvider;
    if (provider == null || _model.isEmpty) return null;
    for (final m in provider.models) {
      if (m.id == _model) return m;
    }
    return null;
  }

  bool get _canSave =>
      _providerId.isNotEmpty &&
      _model.isNotEmpty &&
      _keyCtrl.text.trim().isNotEmpty;

  bool get _hasConfig =>
      _providerId.isNotEmpty ||
      _model.isNotEmpty ||
      _keyCtrl.text.trim().isNotEmpty;

  Future<void> _pickProvider() async {
    final loc = AppLocalizations.of(context)!;
    final list = _catalog;
    if (list == null) return;
    final picked = await _showPicker<CatalogProvider>(
      title: loc.chooseProvider,
      items: list,
      labelOf: (p) => p.name,
      subOf: (p) => p.id,
    );
    if (picked == null) return;
    setState(() {
      _providerId = picked.id;
      _providerName = picked.name;
      _model = '';
      _baseUrlCtrl.text = picked.api;
    });
  }

  Future<void> _pickModel() async {
    final loc = AppLocalizations.of(context)!;
    final provider = _selectedProvider;
    if (provider == null) return;
    final picked = await _showPicker<CatalogModel>(
      title: loc.chooseModel,
      items: provider.models,
      labelOf: (m) => m.name,
      subOf: (m) => m.id,
      trailingOf: (m) => m.attachment ? Icons.photo_camera_outlined : null,
    );
    if (picked == null) return;
    setState(() => _model = picked.id);
  }

  Future<T?> _showPicker<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    required String Function(T) subOf,
    IconData? Function(T)? trailingOf,
  }) {
    final loc = AppLocalizations.of(context)!;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? items
                : items
                    .where((i) =>
                        labelOf(i).toLowerCase().contains(q) ||
                        subOf(i).toLowerCase().contains(q))
                    .toList();
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.78,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.stroke,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: AppText.sectionTitle),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.stroke),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TextField(
                          autofocus: false,
                          cursorColor: AppColors.accent,
                          onChanged: (v) => setSheet(() => query = v),
                          style: AppText.body.copyWith(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            hintText: loc.search,
                            hintStyle: AppText.body.copyWith(
                                color: AppColors.textTertiary, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                loc.noResults,
                                style: AppText.meta,
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final item = filtered[i];
                                final icon = trailingOf?.call(item);
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      Navigator.of(ctx).pop(item),
                                  child: Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 12, 14, 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceHigh,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.stroke),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                labelOf(item),
                                                style: AppText.body.copyWith(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                subOf(item),
                                                style: AppText.meta.copyWith(
                                                    fontSize: 11.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (icon != null)
                                          Icon(icon,
                                              size: 16,
                                              color:
                                                  AppColors.textTertiary),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    final proxyUrl = _proxyCtrl.text.trim();
    await ref.read(appSettingsProvider).setAiProxyUrl(proxyUrl);
    if (_hasConfig) {
      await ref.read(appSettingsProvider).setAiProvider(
            id: _providerId,
            name: _providerName,
            baseUrl: _baseUrlCtrl.text.trim(),
            model: _model,
            apiKey: _keyCtrl.text.trim(),
          );
    }
    ref.invalidate(aiServiceProvider);
    ref.invalidate(trainingServiceProvider);
    unawaited(ref.read(trainingServiceProvider).refresh(force: true));
    if (mounted) _toast(loc.providerSaved);
  }

  Future<void> _remove() async {
    final loc = AppLocalizations.of(context)!;
    await ref.read(appSettingsProvider).clearAiProvider();
    ref.invalidate(aiServiceProvider);
    if (!mounted) return;
    setState(() {
      _providerId = '';
      _providerName = '';
      _model = '';
      _keyCtrl.clear();
      _baseUrlCtrl.clear();
    });
    _toast(loc.providerRemoved);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final model = _selectedModel;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(loc.aiProviderTitle, style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(
              loc.save,
              style: AppText.body.copyWith(
                color: _canSave ? AppColors.accent : AppColors.textTertiary,
                fontWeight: FontWeight.w700,
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
                    Icon(Icons.auto_awesome_rounded,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.aiProviderDesc,
                        style: AppText.body
                            .copyWith(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: AppColors.accent),
                    ),
                  ),
                )
              else ...[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: AppText.meta.copyWith(color: AppColors.accent),
                    ),
                  ),
                Text(loc.provider, style: AppText.label),
                const SizedBox(height: 6),
                _PickerTile(
                  value: _providerName.isNotEmpty
                      ? _providerName
                      : loc.chooseProvider,
                  muted: _providerName.isEmpty,
                  onTap: _catalog == null ? null : _pickProvider,
                ),
                const SizedBox(height: 20),
                Text(loc.model, style: AppText.label),
                const SizedBox(height: 6),
                _PickerTile(
                  value: _model.isNotEmpty ? _model : loc.chooseModel,
                  muted: _model.isEmpty,
                  onTap: _selectedProvider == null ? null : _pickModel,
                ),
                if (model != null && !model.attachment)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      loc.visionNotSupported,
                      style: AppText.meta
                          .copyWith(fontSize: 11.5, color: AppColors.accent),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('API key', style: AppText.label),
                const SizedBox(height: 6),
                Container(
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
                          controller: _keyCtrl,
                          obscureText: _obscureKey,
                          cursorColor: AppColors.accent,
                          onChanged: (_) => setState(() {}),
                          style: AppText.body.copyWith(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            hintText: 'sk-...',
                            hintStyle: AppText.body.copyWith(
                                color: AppColors.textTertiary, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        child: Icon(
                          _obscureKey
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textTertiary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(loc.baseUrl, style: AppText.label),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _baseUrlCtrl,
                    keyboardType: TextInputType.url,
                    cursorColor: AppColors.accent,
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      hintText: 'https://api.example.com/v1',
                      hintStyle: AppText.body.copyWith(
                          color: AppColors.textTertiary, fontSize: 14),
                    ),
                  ),
                ),
                if (_hasConfig) ...[
                  const SizedBox(height: 26),
                  GestureDetector(
                    onTap: _remove,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        loc.removeProvider,
                        style: AppText.body.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 32),
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
                    Icon(Icons.dns_rounded,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.trainingProxyDesc,
                        style: AppText.body
                            .copyWith(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(loc.trainingProxy, style: AppText.label),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stroke),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _proxyCtrl,
                  keyboardType: TextInputType.url,
                  cursorColor: AppColors.accent,
                  style: AppText.body.copyWith(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    hintText: loc.trainingProxyHint,
                    hintStyle: AppText.body.copyWith(
                        color: AppColors.textTertiary, fontSize: 14),
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

class _PickerTile extends StatelessWidget {
  final String value;
  final bool muted;
  final VoidCallback? onTap;

  const _PickerTile({
    required this.value,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: AppText.body.copyWith(
                  color: muted || !enabled
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: enabled ? AppColors.textTertiary : AppColors.stroke,
            ),
          ],
        ),
      ),
    );
  }
}
