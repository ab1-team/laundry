import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/tenant_settings_repository.dart';
import 'settings_provider.dart';

/// Edit the tenant's phone, address, city. Hits `PUT /settings/tenant`
/// with a subset of fields — backend validates the same way as the full
/// update.
class EditTenantContactScreen extends ConsumerStatefulWidget {
  const EditTenantContactScreen({super.key});

  @override
  ConsumerState<EditTenantContactScreen> createState() => _EditTenantContactScreenState();
}

class _EditTenantContactScreenState extends ConsumerState<EditTenantContactScreen> {
  final _phone   = TextEditingController();
  final _address = TextEditingController();
  final _city    = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _city.dispose();
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
          'Alamat & Kontak',
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
            _phone.text   = (tenant['phone']   as String?) ?? '';
            _address.text = (tenant['address'] as String?) ?? '';
            _city.text    = (tenant['city']    as String?) ?? '';
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
          label: 'Nomor WhatsApp / Telepon',
          hint: '62812345678',
          controller: _phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Alamat',
          hint: 'Jalan, nomor, kelurahan, kecamatan',
          controller: _address,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Kota',
          hint: 'Contoh: Jakarta',
          controller: _city,
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final TenantSettingsRepository repo = ref.read(tenantSettingsRepositoryProvider);
      final body = <String, dynamic>{
        'phone':   _phone.text.trim(),
        'address': _address.text.trim(),
        'city':    _city.text.trim(),
      };
      await repo.updateTenant(body);
      ref.invalidate(tenantSettingsProvider);
      if (mounted) {
        _toast(context, 'Alamat & kontak berhasil disimpan');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) _toast(context, 'Gagal: $e');
    }
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
