import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:install_plugin/install_plugin.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_ext.dart';
import '../widgets/app_button.dart';
import 'update_models.dart';
import 'update_service.dart';

/// FutureProvider untuk hasil cek versi. Dipakai oleh [UpdateGate].
final updateCheckProvider = FutureProvider.autoDispose<UpdateCheckResult>((ref) async {
  final svc = ref.watch(updateServiceProvider);
  final pkg = ref.watch(packageInfoProvider);
  return svc.checkForUpdate(pkg);
});

/// Widget yang diletakkan di paling atas tree (di atas MaterialApp.router)
/// untuk:
///   - Menampilkan dialog/blocker kalau update wajib (mandatory)
///   - Menampilkan dialog opsional kalau update tersedia
///   - Trigger download + install APK lewat `install_plugin`
///
/// Karena wajib dipasang SETELAH auth.bootstrap selesai, gate ini
/// dipanggil dari [LaundryApp] / [_RouterApp] setelah router aktif.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  UpdateRequirement? _handled;
  bool _downloading = false;
  double _progress = 0;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('UpdateGate disposed');
    super.dispose();
  }

  void _maybeHandle(UpdateCheckResult result) {
    if (!mounted) return;
    // Hanya tangani 1 kali per requirement level. Kalau user dismiss
    // optional update, tidak muncul lagi sampai requirement naik.
    if (_handled == result.requirement) return;
    if (result.requirement == UpdateRequirement.none) return;
    if (result.info == null) return;

    _handled = result.requirement;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showUpdateSheet(result.info!, result.requirement == UpdateRequirement.mandatory);
    });
  }

  Future<void> _showUpdateSheet(AppVersionInfo info, bool mandatory) async {
    final dismissed = await showModalBottomSheet<bool>(
      context: context,
      // UpdateGate dipasang via `builder` callback MaterialApp.router,
      // sehingga `context` miliknya ada di atas Navigator child router
      // (GoRouter Navigator). Default `useRootNavigator: false` cari
      // Navigator terdekat di atas context — Navigator child router
      // ada di sub-tree, bukan ancestor → crash 'context that does
      // not include a Navigator'.
      // useRootNavigator: true pakai Navigator root dari MaterialApp
      // yang ada di atas UpdateGate, supaya sheet push berhasil.
      useRootNavigator: true,
      isDismissible: !mandatory,
      enableDrag: !mandatory,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _UpdateSheet(
        info: info,
        mandatory: mandatory,
        progress: _progress,
        downloading: _downloading,
      ),
    );
    if (dismissed == true && !mandatory) {
      // User sengaja skip → reset handled agar tidak muncul lagi.
      _handled = UpdateRequirement.none;
    }
  }

  Future<void> _startDownload(AppVersionInfo info) async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _cancelToken = CancelToken();
    });
    try {
      final svc = ref.read(updateServiceProvider);
      final path = await svc.downloadApk(
        info.apkUrl,
        cancelToken: _cancelToken,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      // Tutup sheet, lalu trigger installer sistem. Setelah install
      // selesai Android akan restart app ke versi baru (atau user tekan
      // "Buka" di dialog sistem).
      Navigator.of(context).pop();
      final res = await InstallPlugin.install(path);
      final ok = res['isSuccess'] == true;
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai instalasi: ${res['errorMessage']}')),
        );
        setState(() => _downloading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe + listen hasil cek, lalu trigger sheet kalau perlu.
    //
    // ref.listen saja tidak trigger fetch pada FutureProvider.autoDispose
    // — listener butuh provider aktif dulu. ref.watch mengaktifkan
    // provider (first fetch) dan menjaga dia tetap hidup selama widget
    // mounted; ref.listen attach side-effect tanpa rebuild setiap state
    // change. Kombinasi keduanya = provider aktif + side-effect ringan.
    ref.watch(updateCheckProvider);
    ref.listen<AsyncValue<UpdateCheckResult>>(updateCheckProvider, (prev, next) {
      next.whenData(_maybeHandle);
    });

    return widget.child;
  }
}

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet({
    required this.info,
    required this.mandatory,
    required this.progress,
    required this.downloading,
  });

  final AppVersionInfo info;
  final bool mandatory;
  final double progress;
  final bool downloading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colors;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              mandatory ? 'Update wajib' : 'Update tersedia',
              style: AppTextStyles.headingSm.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Versi baru ${info.latestVersion} sudah tersedia.',
              style: AppTextStyles.bodyMd.copyWith(color: cs.onSurfaceVariant),
            ),
            if (info.changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  info.changelog,
                  style: AppTextStyles.bodySm.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (downloading) ...[
              LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                color: AppColors.primary,
                backgroundColor: cs.outlineVariant,
              ),
              const SizedBox(height: 6),
              Text(
                progress > 0
                    ? 'Mengunduh... ${(progress * 100).toStringAsFixed(0)}%'
                    : 'Mengunduh...',
                style: AppTextStyles.bodySm.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ] else
              Row(
                children: [
                  if (!mandatory)
                    Expanded(
                      child: AppButton(
                        label: 'Nanti',
                        variant: AppButtonVariant.tonal,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  if (!mandatory) const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Update sekarang',
                      onPressed: () {
                        // Trigger download; sheet di-close dari _startDownload
                        // setelah file siap → install.
                        final gate = context
                            .findAncestorStateOfType<_UpdateGateState>();
                        gate?._startDownload(info);
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}