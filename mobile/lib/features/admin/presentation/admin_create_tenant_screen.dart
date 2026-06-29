import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/admin_providers.dart';

/// Super-Admin → form buat tenant + owner sekaligus.
/// Submit → backend `POST /admin/tenants` (atomic).
class AdminCreateTenantScreen extends ConsumerStatefulWidget {
  const AdminCreateTenantScreen({super.key});

  @override
  ConsumerState<AdminCreateTenantScreen> createState() => _AdminCreateTenantScreenState();
}

class _AdminCreateTenantScreenState extends ConsumerState<AdminCreateTenantScreen> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _ownerPassword = TextEditingController();
  bool _saving = false;
  bool _obscurePw = true;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _slugRegex = RegExp(r'^[a-z0-9_-]+$');

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _ownerName.dispose();
    _ownerEmail.dispose();
    _ownerPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin/tenants'),
        ),
        title: Text(
          'Tenant Baru',
          style: AppTextStyles.headlineMd.copyWith(fontSize: 20, color: context.colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SectionLabel(text: 'Informasi Tenant'),
          AppTextField(
            label: 'Nama Tenant',
            hint: 'Contoh: Laundry Aja Sudirman',
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Slug',
            hint: 'laundry-aja-sudirman',
            controller: _slug,
            textInputAction: TextInputAction.next,
            autocorrect: false,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Huruf kecil, angka, dash/underscore. Akan dipakai di URL.',
              style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Telepon (opsional)',
            hint: '+6281234567890',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Kota (opsional)',
            hint: 'Jakarta',
            controller: _city,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Alamat (opsional)',
            hint: 'Jl. ...',
            controller: _address,
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          _SectionLabel(text: 'Akun Owner'),
          AppTextField(
            label: 'Nama Owner',
            hint: 'Nama lengkap',
            controller: _ownerName,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Email Owner',
            hint: 'owner@email.com',
            controller: _ownerEmail,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Password Owner',
            hint: 'Minimal 8 karakter',
            controller: _ownerPassword,
            obscureText: _obscurePw,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(_obscurePw ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePw = !_obscurePw),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            child: Text(_saving ? 'Menyimpan...' : 'Buat Tenant'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final slug = _slug.text.trim();
    final phone = _phone.text.trim();
    final address = _address.text.trim();
    final city = _city.text.trim();
    final ownerName = _ownerName.text.trim();
    final ownerEmail = _ownerEmail.text.trim();
    final ownerPassword = _ownerPassword.text;

    if (name.isEmpty) return _toast(context, 'Nama tenant wajib diisi');
    if (slug.isEmpty || !_slugRegex.hasMatch(slug)) {
      return _toast(context, 'Slug hanya boleh huruf kecil, angka, - dan _');
    }
    if (ownerName.isEmpty) return _toast(context, 'Nama owner wajib diisi');
    if (!_emailRegex.hasMatch(ownerEmail)) return _toast(context, 'Format email owner tidak valid');
    if (ownerPassword.length < 8) return _toast(context, 'Password owner minimal 8 karakter');

    setState(() => _saving = true);
    try {
      final repo = ref.read(adminTenantsRepositoryProvider);
      await repo.create(
        name: name,
        slug: slug,
        phone: phone.isEmpty ? null : phone,
        address: address.isEmpty ? null : address,
        city: city.isEmpty ? null : city,
        ownerName: ownerName,
        ownerEmail: ownerEmail,
        ownerPassword: ownerPassword,
      );
      ref.read(adminTenantsRefreshProvider.notifier).state++;
      if (mounted) {
        _toast(context, 'Tenant + owner berhasil dibuat');
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      final errs = e.errors;
      String msg = e.message;
      if (errs != null) {
        // Tampilkan error field pertama yang ada (biasanya slug atau email).
        for (final key in ['slug', 'owner_email', 'owner_name', 'name']) {
          final list = errs[key];
          if (list is List && list.isNotEmpty) {
            msg = list.first.toString();
            break;
          }
        }
      }
      if (mounted) _toast(context, msg);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) _toast(context, 'Gagal: $e');
    }
  }

  void _toast(BuildContext context, String msg) {
    showAppSnackBar(context, msg);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Text(
        text,
        style: AppTextStyles.labelSm.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}