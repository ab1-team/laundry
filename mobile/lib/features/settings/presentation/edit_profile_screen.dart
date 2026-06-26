import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_model.dart';
import '../../auth/presentation/auth_provider.dart';

/// Edit profil user (nama + email). Hits `PUT /auth/profile`.
/// Email divalidasi unik di server (422 dengan `errors.email` kalau sudah
/// dipakai user lain); kita juga validasi format di client.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;

  // Simple email regex — server tetap memvalidasi lebih ketat.
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (!_hydrated && user != null) {
      _name.text = user.name;
      _email.text = user.email;
      _hydrated = true;
    }
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
          'Edit Profil',
          style: AppTextStyles.headlineMd.copyWith(fontSize: 20, color: context.colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppTextField(
            label: 'Nama',
            hint: 'Nama lengkap',
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Email',
            hint: 'nama@email.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
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
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();

    if (name.isEmpty) {
      _toast(context, 'Nama wajib diisi');
      return;
    }
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      _toast(context, 'Format email tidak valid');
      return;
    }

    setState(() => _saving = true);
    try {
      final AuthRepository repo = ref.read(authRepositoryProvider);
      final UserModel updated = await repo.updateProfile(name: name, email: email);
      // Sync dengan global authProvider.user — header + settings card ikut
      // update tanpa perlu logout/login.
      ref.read(authProvider.notifier).updateUser(updated);
      if (mounted) {
        _toast(context, 'Profil berhasil disimpan');
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      // Backend returns 422 dengan `errors.email` kalau duplikat — tampilkan
      // pesan field-level kalau ada, fallback ke message umum.
      final fieldErr = e.errors?['email'];
      if (mounted) {
        _toast(context, fieldErr is List && fieldErr.isNotEmpty
            ? fieldErr.first.toString()
            : (e.message.isNotEmpty ? e.message : 'Gagal menyimpan profil'));
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