import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/asset_url.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/tenant_settings_repository.dart';
import 'settings_provider.dart';

/// Edit the tenant's name + logo. Hits `PUT /settings/tenant`.
///
/// Logo:
/// - existing logo (from `logo_url`) is shown as preview.
/// - user can pick a new image from gallery / camera — replaces preview
///   until saved (sent as multipart `logo`).
class EditTenantInfoScreen extends ConsumerStatefulWidget {
  const EditTenantInfoScreen({super.key});

  @override
  ConsumerState<EditTenantInfoScreen> createState() => _EditTenantInfoScreenState();
}

class _EditTenantInfoScreenState extends ConsumerState<EditTenantInfoScreen> {
  final _name = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;
  final _picker = ImagePicker();

  String? _existingLogoUrl; // url dari backend (logo_url)
  File? _pickedLogo;       // file lokal yang akan di-upload

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tenantSettingsProvider);
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(
          'Informasi Toko',
          style: AppTextStyles.headlineMd.copyWith(fontSize: 20, color: context.colors.onSurface),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: context.colors.error)),
        ),
        data: (tenant) {
          if (!_hydrated) {
            _name.text = (tenant['name'] as String?) ?? '';
            _existingLogoUrl = resolveAssetUrl(
              (tenant['logo_url'] as String?) ??
                  (tenant['logo_path'] as String?),
            );
            _hydrated = true;
          }
          return _buildForm();
        },
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        AppTextField(
          label: 'Nama Toko',
          hint: 'Contoh: Laundry Aja Sudirman',
          controller: _name,
        ),
        const SizedBox(height: 24),
        Text(
          'Logo Toko',
          style: AppTextStyles.labelLg.copyWith(color: context.colors.onSurface),
        ),
        const SizedBox(height: 12),
        _LogoPicker(
          imageFile: _pickedLogo,
          existingUrl: _pickedLogo == null ? _existingLogoUrl : null,
          onPickGallery: () => _pickLogo(ImageSource.gallery),
          onPickCamera: () => _pickLogo(ImageSource.camera),
          onRemove: _removePickedLogo,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }

  Future<void> _pickLogo(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked == null) return;
      setState(() => _pickedLogo = File(picked.path));
    } on Exception catch (e) {
      if (mounted) _toast(context, 'Gagal memilih gambar: $e');
    }
  }

  void _removePickedLogo() {
    setState(() => _pickedLogo = null);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast(context, 'Nama toko wajib diisi');
      return;
    }
    setState(() => _saving = true);
    try {
      final TenantSettingsRepository repo = ref.read(tenantSettingsRepositoryProvider);
      final body = <String, dynamic>{'name': name};
      await repo.updateTenant(body, logoFile: _pickedLogo);
      ref.invalidate(tenantSettingsProvider);
      // Tenant name also feeds the global authProvider.user.tenantName
      // (used by the AppTabHeader on every tab) — re-fetch /me so the
      // header updates without a manual reload.
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        setState(() {
          _pickedLogo = null;
          _existingLogoUrl = null;
        });
        _toast(context, 'Informasi toko berhasil disimpan');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) _toast(context, 'Gagal: $e');
    }
  }
}

void _toast(BuildContext context, String msg) {
  showAppSnackBar(context, msg);
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.imageFile,
    required this.existingUrl,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemove,
  });

  final File? imageFile;
  final String? existingUrl;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || (existingUrl != null && existingUrl!.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? (imageFile != null
                    ? Image.file(imageFile!, fit: BoxFit.cover, width: 128, height: 128)
                    : Image.network(existingUrl!, fit: BoxFit.cover, width: 128, height: 128,
                        errorBuilder: (_, __, ___) => _placeholder(context)))
                : _placeholder(context),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.onSurface,
                  side: BorderSide(color: context.colors.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.onSurface,
                  side: BorderSide(color: context.colors.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (imageFile != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Batalkan pilihan'),
          ),
        ],
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return Icon(
      Icons.storefront_outlined,
      size: 56,
      color: context.colors.onSurfaceVariant,
    );
  }
}
