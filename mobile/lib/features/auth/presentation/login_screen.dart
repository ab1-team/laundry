import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;
    final ok = await ref.read(authProvider.notifier).login(email, pass);
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final isLoading = state.loading;
    final brightness = Theme.of(context).brightness;
    final systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: context.colors.surface,
      systemNavigationBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: context.colors.surface,
      systemNavigationBarContrastEnforced: false,
    );

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlay,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            // Logo
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.local_laundry_service, color: AppColors.onPrimary, size: 32),
            ),
            const SizedBox(height: 20),
            Text('LaundryAja', style: AppTextStyles.headlineMd.copyWith(color: context.colors.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Sistem Manajemen Operasional Laundry',
              style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Form card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Email',
                    hint: 'nama@email.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline,
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Kata Sandi',
                    hint: '••••••••',
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    prefixIcon: Icons.lock_outline,
                    onChanged: (_) => _clearError(),
                    suffixIcon: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _obscurePass = !_obscurePass),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: context.colors.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Lupa Kata Sandi?',
                        style: AppTextStyles.labelLg.copyWith(color: AppColors.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Masuk',
                    onPressed: isLoading ? null : _submit,
                    loading: isLoading,
                    icon: Icons.arrow_forward,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  state.error!,
                  style: AppTextStyles.bodyMd.copyWith(color: context.colors.error),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 32),
            Text(
              '© 2024 LaundryAja. Seluruh Hak Cipta Dilindungi.',
              style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () {}, child: const Text('Bantuan')),
                const SizedBox(width: 16),
                TextButton(onPressed: () {}, child: const Text('Ketentuan Layanan')),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// Clear stale auth error when user mulai edit field — UX standar:
  /// pesan error sebelumnya tidak "menempel" setelah user koreksi input.
  void _clearError() {
    ref.read(authProvider.notifier).clearError();
  }
}
