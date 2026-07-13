import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:install_plugin/install_plugin.dart';

import '../router/app_router.dart';
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
  ConsumerState<UpdateGate> createState() => UpdateGateState();
}

/// GlobalKey yang di-attach ke UpdateGate widget di call-site
/// (`UpdateGate(key: updateGateKey, child: ...)`). Dipakai oleh
/// _UpdateSheet untuk akses _UpdateGateState (button handler panggil
/// _startDownload). Key HARUS terikat ke widget Element supaya
/// currentState tidak return null.
final GlobalKey<UpdateGateState> updateGateKey = GlobalKey<UpdateGateState>();

class UpdateGateState extends ConsumerState<UpdateGate> {
  UpdateRequirement? _handled;

  /// State lokal (UI thread) di gate tidak dipakai untuk rebuild sheet —
  /// ValueNotifier dipakai supaya _UpdateSheet (yang di-build sekali
  /// oleh showModalBottomSheet) bisa listen perubahan progress/downloading
  /// via ValueListenableBuilder. Tanpa notifier, sheet stuck di nilai
  /// awal karena tidak ada mekanisme rebuild dari luar.
  final ValueNotifier<bool> _downloading = ValueNotifier<bool>(false);
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('UpdateGate disposed');
    _downloading.dispose();
    _progress.dispose();
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
    // UpdateGate di-mount via `builder` callback MaterialApp.router.
    // Navigator.of(context) gagal di sana karena Navigator di-abstract
    // ke Router API — context builder tidak punya Navigator ancestor.
    //
    // Solusi: pakai AppRouter.rootKey (GlobalKey yang di-share dengan
    // GoRouter(navigatorKey:)) → currentContext = context dari root
    // Navigator, descendants Navigator tersedia untuk push modal.
    final navCtx = AppRouter.rootKey.currentContext;
    if (navCtx == null) {
      // Router belum siap (cold start) → skip sheet, next attempt akan
      // retry saat user trigger lagi.
      return;
    }
    final dismissed = await showDialog<bool>(
      context: navCtx,
      // Centered dialog — lebih konvensional untuk 'update tersedia'
      // dibanding bottom sheet yang mengambil setengah layar dan
      // menutupi konten dashboard. Dengan Dialog widget, sheet muncul
      // di tengah dengan backdrop gelap full-screen.
      //
      // Close mechanism off:
      // - barrierDismissible: tap-outside / barrier dismiss tidak
      //   berfungsi. User HANYA bisa close via button 'Nanti'
      //   (optional, eksplisit) atau setelah flow _startDownload
      //   selesai (gate.pop setelah InstallPlugin.install return).
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: _UpdateSheet(
          info: info,
          mandatory: mandatory,
          // Pass ValueNotifier (bukan value) supaya sheet bisa listen
          // perubahan progress dari gate via ValueListenableBuilder.
          // Sebelumnya pass _progress/_downloading sebagai value, sheet
          // tidak rebuild saat download callback fire.
          progress: _progress,
          downloading: _downloading,
          // Pass selfKey supaya sheet bisa panggil _startDownload tanpa
          // findAncestorStateOfType (yang return null karena modal route
          // context tidak punya _UpdateGate di ancestor tree).
          gateKey: updateGateKey,
        ),
      ),
    );
    if (dismissed == true && !mandatory) {
      // User sengaja skip → reset handled agar tidak muncul lagi.
      _handled = UpdateRequirement.none;
    }
  }

  Future<void> _startDownload(AppVersionInfo info) async {
    _downloading.value = true;
    _progress.value = 0;
    _cancelToken = CancelToken();
    try {
      final svc = ref.read(updateServiceProvider);
      final path = await svc.downloadApk(
        info.apkUrl,
        cancelToken: _cancelToken,
        onProgress: (p) {
          // Update ValueNotifier (bukan setState) supaya ValueListenableBuilder
          // di _UpdateSheet fire rebuild. setState() di gate tidak affect
          // sheet yang di-build sekali oleh showModalBottomSheet.
          if (mounted) _progress.value = p;
        },
      );
      if (!mounted) return;
      // Modal TIDAK di-pop di sini. Android install dialog (system overlay
      // dari PackageInstaller) muncul di atas Flutter UI — modal tetap
      // visible di belakangnya selama user interaction dengan install
      // prompt. Auto-pop modal di sini akan trigger restart/recreate
      // app context yang bisa hilang state form user, plus bikin
      // transisi 'download selesai → install dialog' terasa abrupt.
      //
      // Modal di-pop manual di akhir _startDownload setelah
      // InstallPlugin.install return (sukses/gagal/dibatalkan user).
      final res = await InstallPlugin.install(path);
      if (!mounted) return;
      final ok = res['isSuccess'] == true;
      // Pop modal setelah InstallPlugin return — user sudah selesai
      // interact dengan Android system install dialog (tekan Install,
      // Cancel, atau background ke launcher). Modal tetap visible
      // selama interaction itu, jadi user tidak kehilangan context
      // 'apa yang sedang terjadi'.
      AppRouter.rootKey.currentState?.pop();
      if (ok) {
        // Install sukses → APK baru ter-install tapi app belum restart
        // otomatis. User harus manual buka dari launcher. Kasih hint
        // supaya mereka tidak bingung.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update terpasang. Buka kembali aplikasi dari launcher untuk memuat versi baru.'),
            duration: Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai instalasi: ${res['errorMessage'] ?? 'dibatalkan'}')),
        );
      }
      _downloading.value = false;
      _handled = UpdateRequirement.none;
    } catch (e) {
      if (!mounted) return;
      _downloading.value = false;
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

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({
    required this.info,
    required this.mandatory,
    required this.gateKey,
    required this.downloading,
    required this.progress,
  });

  final AppVersionInfo info;
  final bool mandatory;

  /// GlobalKey ke _UpdateGateState — dipakai untuk panggil _startDownload
  /// dari button handler. findAncestorStateOfType tidak reliable karena
  /// sheet di-build oleh showModalBottomSheet dengan modal route context
  /// yang tidak punya _UpdateGate di ancestor tree.
  final GlobalKey<UpdateGateState> gateKey;

  /// ValueNotifier — dipakai bersama dengan _UpdateGateState supaya
  /// sheet rebuild saat progress berubah. Penting karena sheet di-build
  /// sekali oleh showModalBottomSheet (tidak auto-rebuild saat UpdateGate
  /// state berubah), jadi butuh ValueListenableBuilder untuk listen
  /// perubahan dari luar widget tree.
  final ValueListenable<bool> downloading;
  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
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
            // ValueListenableBuilder mendengarkan ValueNotifier dari
            // _UpdateGateState — saat gate update progress (callback
            // download), notifier fire → builder re-run → progress bar
            // rebuild dengan nilai baru. Tanpa ValueListenableBuilder,
            // sheet stuck di nilai awal karena showModalBottomSheet
            // builder dipanggil sekali.
            ValueListenableBuilder<bool>(
              valueListenable: downloading,
              builder: (_, isDownloading, __) {
                if (!isDownloading) {
                  return Row(
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
                            //
                            // Pakai gateKey.currentState langsung — modal route
                            // context tidak punya _UpdateGate di ancestor tree
                            // jadi findAncestorStateOfType return null (button
                            // silent no-op).
                            gateKey.currentState?._startDownload(info);
                          },
                        ),
                      ),
                    ],
                  );
                }
                return ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, p, __) => Column(
                    children: [
                      LinearProgressIndicator(
                        value: p > 0 ? p : null,
                        color: AppColors.primary,
                        backgroundColor: cs.outlineVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p > 0
                            ? 'Mengunduh... ${(p * 100).toStringAsFixed(0)}%'
                            : 'Mengunduh...',
                        style: AppTextStyles.bodySm.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}