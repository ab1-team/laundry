import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/wa/wa_status_labels.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import 'settings_provider.dart';

/// Hubungkan WhatsApp via Evolution API.
///
/// Flow:
/// 1. Owner input nama instance + nomor HP.
/// 2. Tap "Buat Pairing Code" → POST /wa-pairing → dapat 8-char code.
/// 3. Tampilkan kode besar + countdown 60 detik.
/// 4. Owner buka WA → Settings → Linked Devices → "Link with phone
///    number" → ketik kode. Status "Terhubung" begitu WA di-HP mengkonfirmasi.
///
/// Catatan: pairing code expire ~60s sekali pakai. Tombol berubah jadi
/// "Buat Ulang Code" saat expired atau setelah generate.
class WhatsAppScreen extends ConsumerStatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  ConsumerState<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends ConsumerState<WhatsAppScreen> {
  final _phone = TextEditingController();

  // Pairing state
  String? _pairingCode;
  DateTime? _codeExpiresAt;
  Timer? _countdown;
  int _secondsLeft = 0;
  bool _busy = false;

  // Trigger notif — sinkron dengan tenants.wa_settings.notify_on.
  bool _isActive = false;

  late Set<String> _notifyOn;

  /// Custom template WA per status — key = status.key, value = template string.
  /// Controllers hidup di state ini karena masing-masing tile butuh rebuild
  /// sendiri saat user edit (preview ikut update). Hydrated dari
  /// `wa_settings.templates` di `_hydrateFromTenant`.
  ///
  /// Empty string = "pakai default backend" (di-filter saat save).
  final Map<String, TextEditingController> _templateCtrls = {
    for (final s in WaStatusLabels.all) s.key: TextEditingController(),
  };
  // Force refresh preview saat user tap chip (selection baseOffset berubah).
  // Pakai ValueNotifier per status untuk granular rebuild tanpa setState seluruh screen.
  final Map<String, ValueNotifier<int>> _templatePreviewTickers = {
    for (final s in WaStatusLabels.all) s.key: ValueNotifier<int>(0),
  };

  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _notifyOn = {'masuk', 'selesai', 'diambil'}; // default backend
    // Hook controller listener → bump ticker supaya preview rebuild.
    for (final entry in _templateCtrls.entries) {
      entry.value.addListener(() => _templatePreviewTickers[entry.key]!.value++);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _countdown?.cancel();
    for (final c in _templateCtrls.values) {
      c.dispose();
    }
    for (final t in _templatePreviewTickers.values) {
      t.dispose();
    }
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    _codeExpiresAt = DateTime.now().add(Duration(seconds: seconds));
    _secondsLeft = seconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = _codeExpiresAt!.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        t.cancel();
        setState(() {
          _secondsLeft = 0;
          _pairingCode = null;
        });
      } else {
        setState(() => _secondsLeft = left);
      }
    });
  }

  Future<void> _resetConnection() async {
    // Destructive: kasih konfirmasi sebelum logout WA di HP owner.
    // Sekali logout, owner harus pair ulang via tombol "Buat Pairing Code".
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Koneksi WhatsApp?'),
        content: const Text(
          'Sesi WhatsApp di HP owner akan diputus. Untuk menerima '
          'notifikasi lagi, owner harus pairing ulang dengan kode baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _syncTriggered = false; // allow re-sync setelah reset
    });
    try {
      await ref.read(whatsAppRepositoryProvider).resetConnection();
      if (!mounted) return;
      setState(() {
        _isActive = false;
        _pairingCode = null;
        _phone.text = '';
      });
      _countdown?.cancel();
      ref.invalidate(tenantSettingsProvider);
      showAppSnackBar(context, 'Koneksi WhatsApp di-reset.',
          type: AppSnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Gagal reset: $e',
          type: AppSnackBarType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateCode() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      showAppSnackBar(context, 'Nomor WhatsApp wajib diisi.',
          type: AppSnackBarType.error);
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(whatsAppRepositoryProvider);
      // Backend auto-generate nama instance (prefix LaundryAja-XXXXXX)
      // kalau wa_settings.instance belum ada — mobile tidak perlu input.
      final result = await repo.requestPairingCode(phone);
      final code = result['pairing_code'] as String?;
      final expiresIn = (result['expires_in'] as int?) ?? 60;

      if (!mounted) return;

      if (code == null || code.isEmpty) {
        throw 'Backend tidak mengembalikan pairing code.';
      }

      setState(() {
        _pairingCode = code;
        _syncTriggered = false; // re-sync after pair completes
      });
      _startCountdown(expiresIn);
      ref.invalidate(tenantSettingsProvider);

      showAppSnackBar(
        context,
        'Pairing code dibuat. Masukkan di WhatsApp dalam ${expiresIn}s.',
        type: AppSnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Gagal: $e', type: AppSnackBarType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _busy = true);
    try {
      // Collect template payloads — skip empty (server fallback ke default).
      final templates = <String, String>{};
      for (final entry in _templateCtrls.entries) {
        final v = entry.value.text.trim();
        if (v.isNotEmpty) templates[entry.key] = entry.value.text;
      }

      final payload = <String, dynamic>{
        'enabled': _notifyOn.isNotEmpty,
        'notify_on': _notifyOn.toList(),
      };
      if (templates.isNotEmpty) {
        payload['templates'] = templates;
      }

      await ref.read(whatsAppRepositoryProvider).updateWaSettings(payload);
      ref.invalidate(tenantSettingsProvider);
      if (!mounted) return;
      showAppSnackBar(context, 'Pengaturan tersimpan.',
          type: AppSnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Gagal simpan: $e', type: AppSnackBarType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _hydrateFromTenant(Map<String, dynamic> tenant) {
    final wa = tenant['wa_settings'];
    final newActive = wa is Map &&
        wa['enabled'] == true &&
        (wa['instance'] as String?)?.isNotEmpty == true;

    if (!_hydrated) {
      // First sync: seed phone + notify_on + templates dari backend.
      if (wa is Map) {
        _phone.text = (wa['owner_number'] as String?) ?? '';
        final no = wa['notify_on'];
        if (no is List) {
          _notifyOn = no.map((e) => e.toString()).toSet();
        }
        final templates = wa['templates'];
        if (templates is Map) {
          for (final entry in templates.entries) {
            final c = _templateCtrls[entry.key.toString()];
            if (c != null && c.text.isEmpty) {
              c.text = entry.value?.toString() ?? '';
            }
          }
        }
      }
      _hydrated = true;
    }

    // Setiap kali tenant data berubah, sync _isActive. Kalau baru saja
    // berubah false → true (pairing sukses di backend), clear pairing card
    // + countdown karena kode sudah tidak relevan.
    if (newActive != _isActive) {
      setState(() {
        _isActive = newActive;
        if (newActive) {
          _pairingCode = null;
          _countdown?.cancel();
          _secondsLeft = 0;
        }
      });
    } else {
      _isActive = newActive;
    }

    // First hydrate selesai → trigger sync ke Evolution untuk catch
    // skenario owner re-pair manual di WA tanpa lewat endpoint /wa-pairing.
    // Backend akan update wa_settings.enabled kalau state mismatch, dan
    // invalidate tenant provider refresh data ini.
    if (_hydrated && !_syncTriggered) {
      _syncTriggered = true;
      _syncConnectionState();
    }
  }

  bool _syncTriggered = false;

  Future<void> _syncConnectionState() async {
    try {
      final result =
          await ref.read(whatsAppRepositoryProvider).fetchConnectionState();
      if (!mounted) return;
      final syncedEnabled = result['enabled'] == true;
      if (syncedEnabled != _isActive) {
        // Force refetch tenant — backend mungkin sudah update wa_settings.
        ref.invalidate(tenantSettingsProvider);
      }
    } catch (_) {
      // Sync optional — kalau gagal (timeout, Evolution down), abaikan.
      // User tinggal manual tekan "Buat Pairing Code" atau "Reset Koneksi".
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantAsync = ref.watch(tenantSettingsProvider);

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(
          'WhatsApp Gateway',
          style: AppTextStyles.headlineMd.copyWith(
            fontSize: 20,
            color: context.colors.onSurface,
          ),
        ),
      ),
      body: tenantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: context.colors.error)),
        ),
        data: (tenant) {
          _hydrateFromTenant(tenant);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _StatusCard(waSettings: tenant['wa_settings']),
              const SizedBox(height: 24),
              // Lock nomor owner ketika WA sudah aktif — kalau mau ganti
              // nomor, owner harus disconnect dulu. Cegah input diam-diam
              // yang tidak terkirim ke backend.
              AppTextField(
                label: 'Nomor WhatsApp Owner',
                hint: '081234567890',
                controller: _phone,
                keyboardType: TextInputType.phone,
                enabled: !_isActive,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _generateCode,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_2),
                label: Text(_pairingCode == null
                    ? 'Buat Pairing Code'
                    : 'Buat Ulang Code'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              // Reset Koneksi hanya relevan saat WA sudah terhubung —
              // pisah dari pairing flow biar jelas intent-nya. Saat WA
              // belum aktif, owner cukup pakai tombol Buat Pairing Code di atas.
              if (_isActive) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _busy ? null : _resetConnection,
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('Reset Koneksi'),
                ),
              ],
              if (_pairingCode != null && !_isActive) ...[
                const SizedBox(height: 20),
                _PairingCodeCard(
                  code: _pairingCode!,
                  secondsLeft: _secondsLeft,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: _pairingCode!));
                    showAppSnackBar(context, 'Kode disalin ke clipboard.',
                        type: AppSnackBarType.success);
                  },
                ),
              ],
              const SizedBox(height: 24),
              _SectionGroup(
                title: 'Notifikasi WhatsApp',
                child: TemplateEditorScope(
                  controllers: _templateCtrls,
                  tickers: _templatePreviewTickers,
                  child: _StatusEditorList(
                    tenantName: tenant['name'] as String? ?? 'Laundry Anda',
                    selected: _notifyOn,
                    onToggle: (s, on) {
                      setState(() {
                        on ? _notifyOn.add(s) : _notifyOn.remove(s);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: _busy ? null : _saveSettings,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: const Text('Simpan Pengaturan'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ====================================================================
// Sub-widgets — semua pakai pola yang sama dengan SettingsScreen
// (card dengan border + radius 32, soft shadow, AppTextStyles).
// ====================================================================

/// Section bergaya `_MenuGroup` di SettingsScreen — judul kecil di atas,
/// card berisi list. Konsisten dengan halaman settings lain.
class _SectionGroup extends StatelessWidget {
  const _SectionGroup({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: AppTextStyles.labelSm.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        // Pakai Material elevation (Flutter-recommended way untuk card
        // shadow). Sebelumnya BoxDecoration+boxShadow nge-render shadow
        // kotak di pojok rounded (32px) karena ListView parent clip
        // tidak cukup lebar untuk blur 16 + radius 32. Material widget
        // nge-cast shadow persis ke border-radius — rounded smooth.
        Material(
          color: context.colors.surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          elevation: 1,
          shadowColor: AppColors.primary.withValues(alpha: 0.08),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: context.colors.surfaceContainerHigh,
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Status koneksi: card kecil di atas — connected (hijau) / off (abu).
/// "Connected" actual butuh polling `connectionState` Evolution, hold off
/// — untuk MVP cukup reflect `wa_settings.enabled`.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.waSettings});
  final dynamic waSettings;

  @override
  Widget build(BuildContext context) {
    final wa = waSettings is Map ? waSettings : const {};
    final enabled = wa['enabled'] == true;
    final instance = wa['instance'] as String?;
    final connected = enabled && (instance?.isNotEmpty ?? false);

    final color = connected
        ? AppColors.secondary
        : context.colors.outline;
    final label = connected ? 'Aktif' : 'Belum Diaktifkan';
    final icon = connected ? Icons.link : Icons.link_off;
    final subtitle = instance != null && instance.isNotEmpty
        ? 'Instance: $instance'
        : 'Buat pairing code di bawah untuk menghubungkan.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.surfaceContainerHigh, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $label',
                  style: AppTextStyles.titleLg.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card besar berisi pairing code + countdown + step instruksi.
/// Style: secondaryContainer background (sama dengan app-wide) + radius 32.
class _PairingCodeCard extends StatelessWidget {
  const _PairingCodeCard({
    required this.code,
    required this.secondsLeft,
    required this.onCopy,
  });
  final String code;
  final int secondsLeft;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final formatted = code.length == 8
        ? '${code.substring(0, 4)}-${code.substring(4)}'
        : code;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 18, color: context.colors.onSecondaryContainer),
              const SizedBox(width: 6),
              Text(
                'Berlaku ${secondsLeft}d',
                style: AppTextStyles.labelLg.copyWith(
                  color: context.colors.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Kode monospace 36pt, letter-spacing 6 — mudah dibaca manual.
          Center(
            child: SelectableText(
              formatted,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: context.colors.onSecondaryContainer,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Salin Kode'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cara pakai:',
                  style: AppTextStyles.labelLg.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                _Step(n: 1, text: 'Buka WhatsApp di HP owner.'),
                _Step(n: 2, text: 'Settings → Linked Devices.'),
                _Step(
                  n: 3,
                  text:
                      'Pilih "Link with phone number", masukkan kode di atas.',
                ),
                _Step(n: 4, text: 'Tunggu hingga status berubah menjadi Aktif.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySm.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gabungan switch trigger + template editor per status, dalam 1 list.
/// Tiap row: Switch on/off + label status + badge "Custom" kalau template
/// overridden. Tap header (selain switch) → expand panel editor template
/// (TextField + chip variabel + preview). Expander state local per-tile.
///
/// Sebelumnya dipisah jadi `_NotifyOnList` (switch saja) + `_TemplateAccordion`
/// (template saja di section terpisah). Digabung supaya owner lihat semua
/// kontrol untuk 1 status dalam 1 tempat.
class _StatusEditorList extends StatelessWidget {
  const _StatusEditorList({
    required this.tenantName,
    required this.selected,
    required this.onToggle,
  });
  final String tenantName;
  final Set<String> selected;
  final void Function(String status, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < WaStatusLabels.all.length; i++) ...[
          _StatusEditorTile(
            status: WaStatusLabels.all[i],
            tenantName: tenantName,
            enabled: selected.contains(WaStatusLabels.all[i].key),
            onToggle: (v) => onToggle(WaStatusLabels.all[i].key, v),
          ),
          if (i < WaStatusLabels.all.length - 1)
            Divider(
              height: 1,
              thickness: 1,
              color: context.colors.outlineVariant,
              indent: 16,
              endIndent: 16,
            ),
        ],
      ],
    );
  }
}

/// Single status editor (switch + template panel). Controller + ticker
/// diakses via [TemplateEditorScope] — pattern sederhana untuk baca
/// state parent tanpa prop drilling. Parent State holder ada di
/// `_WhatsAppScreenState` dan diekspos lewat scope.
///
/// Trailing Switch dipisah dari title row supaya tap Switch tidak
/// trigger expand tile (default ExpansionTile tap area menelan seluruh
/// header row). Chevron manual ditambahkan karena override trailing
/// menghilangkan default arrow icon.
class _StatusEditorTile extends StatelessWidget {
  const _StatusEditorTile({
    required this.status,
    required this.tenantName,
    required this.enabled,
    required this.onToggle,
  });
  final WaStatus status;
  final String tenantName;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scope = TemplateEditorScope.of(context);
    final controller = scope.controllers[status.key]!;
    final ticker = scope.tickers[status.key]!;

    return Theme(
      // Strip default ExpansionTile divider/dense untuk visual konsisten
      // dengan section group di atasnya.
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                status.label,
                style: AppTextStyles.bodyLg.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) {
                if (value.text.trim().isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Custom',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        // Trailing Switch dipisah dari title row supaya tap Switch tidak
        // trigger expand tile. ExpansionTile default trailing (arrow icon)
        // di-override dengan Switch + chevron manual.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: enabled,
              onChanged: onToggle,
            ),
            // Chevron indicator — ExpansionTile tidak render default arrow
            // kalau trailing di-override, jadi kita gambar manual.
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          TextField(
            controller: controller,
            maxLines: 6,
            minLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: 'Kosongkan untuk pakai template default...',
              hintStyle: AppTextStyles.bodyMd.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              filled: true,
              fillColor: context.colors.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: context.colors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: context.colors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: const BorderSide(
                  color: AppColors.secondary,
                  width: 2,
                ),
              ),
              counterStyle: AppTextStyles.labelSm.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            style: AppTextStyles.bodyMd.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          // Chip variabel — tap untuk insert di posisi cursor TextField.
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: WaStatusLabels.variables.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final v = WaStatusLabels.variables[i];
                return ActionChip(
                  label: Text(v.label),
                  labelStyle: AppTextStyles.labelLg.copyWith(
                    color: context.colors.onSurface,
                  ),
                  backgroundColor: context.colors.surfaceContainerHigh,
                  side: BorderSide(color: context.colors.outline),
                  onPressed: () => _insertAtCursor(controller, v.token),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Preview panel — render template dengan sample data.
          ValueListenableBuilder<int>(
            valueListenable: ticker,
            builder: (_, _, _) {
              final tpl = controller.text;
              final preview = tpl.trim().isEmpty
                  ? '(Kosong — pakai template default saat notif terkirim)'
                  : renderWaPreview(
                      tpl,
                      WaSampleVars.forStatus(status.key, tenantName: tenantName),
                    );
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: AppTextStyles.labelSm.copyWith(
                        color: context.colors.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      preview,
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.colors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Insert token ke TextEditingController di posisi kursor saat ini.
  /// Kalau selection invalid (kosong/blom focus), append di akhir text.
  void _insertAtCursor(TextEditingController controller, String token) {
    final selection = controller.selection;
    final text = controller.text;
    final hasSelection = selection.start >= 0 && selection.end >= 0;
    final start = hasSelection ? selection.start : text.length;
    final end = hasSelection ? selection.end : text.length;

    final newText = text.replaceRange(start, end, token);
    final newCursor = start + token.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}

/// InheritedWidget untuk share controller + ticker map ke semua tile tanpa
/// prop drilling 5 levels. Pattern ini cukup untuk 5 tile — kalau jumlah
/// status berkembang (>10) atau ada nested editor, switch ke Riverpod.
class TemplateEditorScope extends InheritedWidget {
  const TemplateEditorScope({
    super.key,
    required this.controllers,
    required this.tickers,
    required super.child,
  });
  final Map<String, TextEditingController> controllers;
  final Map<String, ValueNotifier<int>> tickers;

  static TemplateEditorScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TemplateEditorScope>();
    assert(scope != null, 'TemplateEditorScope.of() called outside scope');
    return scope!;
  }

  @override
  bool updateShouldNotify(TemplateEditorScope oldWidget) =>
      controllers != oldWidget.controllers || tickers != oldWidget.tickers;
}
