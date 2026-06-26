import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';

/// Static FAQ screen. No backend — the contents live in this file because
/// the answers are short, stable, and don't need CMS support.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = <_FaqEntry>[
    _FaqEntry(
      q: 'Bagaimana cara membuat order baru?',
      a: 'Buka tab Order → ketuk tombol "Order Baru" di pojok kanan bawah. Pilih '
         'pelanggan (atau buat baru), lalu pilih layanan dan isi jumlah.',
    ),
    _FaqEntry(
      q: 'Bagaimana cara mencatat pembayaran?',
      a: 'Buka detail order → gulir ke bagian "Pembayaran" → ketuk "Catat '
         'Pembayaran". Masukkan nominal, pilih metode (cash/transfer/QRIS), lalu simpan.',
    ),
    _FaqEntry(
      q: 'Bagaimana cara mengupdate status order?',
      a: 'Di halaman detail order, gunakan tombol "Update Status" pada '
         'pipeline di atas. Status berpindah otomatis: Masuk → Dicuci → Selesai → Diambil.',
    ),
    _FaqEntry(
      q: 'Apa bedanya owner dan operator?',
      a: 'Owner punya akses penuh termasuk laporan keuangan dan kelola '
         'layanan. Operator hanya bisa input order, pelanggan, dan pembayaran.',
    ),
    _FaqEntry(
      q: 'Apakah data saya aman?',
      a: 'Setiap akun terisolasi per tenant. Login menggunakan token Sanctum '
         'yang disimpan terenkripsi di perangkat.',
    ),
  ];

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
          'Bantuan',
          style: AppTextStyles.headlineMd.copyWith(fontSize: 20, color: context.colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
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
            child: Column(
              children: [
                for (int i = 0; i < _faqs.length; i++) ...[
                  Theme(
                    // Strip the default ExpansionTile dividers/borders so
                    // we control spacing inside the card chrome above.
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      iconColor: AppColors.secondary,
                      collapsedIconColor: context.colors.onSurfaceVariant,
                      title: Text(_faqs[i].q, style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface)),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _faqs[i].a,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: context.colors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _faqs.length - 1)
                    Divider(height: 1, color: context.colors.outlineVariant, indent: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqEntry {
  const _FaqEntry({required this.q, required this.a});
  final String q;
  final String a;
}