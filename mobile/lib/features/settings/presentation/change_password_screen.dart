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
import '../data/password_repository.dart';
import 'settings_provider.dart';

/// Change the authenticated user's password. Hits `PUT /auth/password`.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current     = TextEditingController();
  final _new         = TextEditingController();
  final _confirm     = TextEditingController();
  bool _saving       = false;
  bool _obscureCur   = true;
  bool _obscureNew   = true;
  bool _obscureConf  = true;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(
          'Ubah Password',
          style: AppTextStyles.headlineMd.copyWith(fontSize: 20, color: context.colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppTextField(
            label: 'Password Lama',
            hint: 'Masukkan password saat ini',
            controller: _current,
            obscureText: _obscureCur,
            suffixIcon: IconButton(
              icon: Icon(_obscureCur ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureCur = !_obscureCur),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Password Baru',
            hint: 'Minimal 8 karakter',
            controller: _new,
            obscureText: _obscureNew,
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Konfirmasi Password Baru',
            hint: 'Ketik ulang password baru',
            controller: _confirm,
            obscureText: _obscureConf,
            suffixIcon: IconButton(
              icon: Icon(_obscureConf ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConf = !_obscureConf),
            ),
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
    final cur = _current.text;
    final next = _new.text;
    final conf = _confirm.text;

    if (cur.isEmpty || next.isEmpty || conf.isEmpty) {
      _toast(context, 'Semua field wajib diisi');
      return;
    }
    if (next.length < 8) {
      _toast(context, 'Password baru minimal 8 karakter');
      return;
    }
    if (next != conf) {
      _toast(context, 'Konfirmasi password tidak cocok');
      return;
    }
    if (next == cur) {
      _toast(context, 'Password baru harus berbeda dengan yang lama');
      return;
    }

    setState(() => _saving = true);
    try {
      final PasswordRepository repo = ref.read(passwordRepositoryProvider);
      await repo.changePassword(current: cur, next: next);
      if (mounted) {
        _toast(context, 'Password berhasil diubah');
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      // Backend returns 422 with `errors.current_password` when the old
      // password doesn't match — surface that on the right field.
      final fieldErr = e.errors?['current_password'];
      if (mounted) {
        _toast(context, fieldErr is List && fieldErr.isNotEmpty
            ? fieldErr.first.toString()
            : (e.message.isNotEmpty ? e.message : 'Gagal mengubah password'));
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