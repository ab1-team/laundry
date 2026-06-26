import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/compact_currency.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tab_header.dart';
import '../../../core/widgets/order_summary_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/presentation/auth_provider.dart';
import 'orders_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onNavTap});
  final ValueChanged<int>? onNavTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final ordersAsync = ref.watch(activeOrdersProvider);
    // Untuk card sempit (Piutang) supaya nominal panjang tidak overflow.
    final rupiahShort = formatRupiahShort;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          AppTabHeader(
            onTrailingTap: () => context.push('/settings'),
          ), // reads tenantName from authProvider automatically

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeOrdersProvider);
              },
              child: ListView(
                padding: EdgeInsets.only(bottom: 140),
                children: [
                  // Greeting — DESIGN.md: small label greeting on top, title-lg headline below.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${user?.role == 'operator' ? 'Operator' : 'Owner'}',
                          style: AppTextStyles.labelLg.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text('Overview Hari Ini', style: AppTextStyles.titleLg),
                      ],
                    ),
                  ),

                  // Stat cards
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: ordersAsync.when(
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => _ErrorBox(message: e.toString(), onRetry: () => ref.invalidate(activeOrdersProvider)),
                      data: (orders) {
                        final active = orders.length;
                        final piutang = orders.fold<double>(0, (s, o) => s + o.remaining);
                        return Column(
                          children: [
                            StatCard(
                              title: 'Total Order Aktif',
                              value: '$active',
                              subtitle: '+${orders.where((o) => o.status == 'selesai').length} dari kemarin',
                              variant: StatCardVariant.primary,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: StatCard(
                                    title: 'Menunggu Diambil',
                                    value: '${orders.where((o) => o.status == 'selesai').length}',
                                    unit: 'Paket',
                                    valueColorOverride: AppColors.secondary,
                                    variant: StatCardVariant.default_,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: StatCard(
                                    title: 'Piutang',
                                    value: rupiahShort(piutang),
                                    unit: '${orders.where((o) => o.remaining > 0).length} Pelanggan',
                                    variant: StatCardVariant.attention,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Quick actions — DESIGN.md: label-lg "Aksi Cepat" with onSurfaceVariant.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Text(
                            'Aksi Cepat',
                            style: AppTextStyles.labelLg.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(right: 20),
                            children: [
                              AppButton(
                                label: 'Buat Order',
                                onPressed: () => context.push('/orders/create'),
                                variant: AppButtonVariant.secondary,
                                icon: Icons.add,
                                fullWidth: false,
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                label: 'Daftar Order',
                                onPressed: () => context.push('/orders'),
                                variant: AppButtonVariant.tonal,
                                icon: Icons.list_alt,
                                fullWidth: false,
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                label: 'Customer',
                                onPressed: () => context.push('/customers'),
                                variant: AppButtonVariant.tonal,
                                icon: Icons.person_outline,
                                fullWidth: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Order Terbaru — DESIGN.md: label-lg onSurfaceVariant title.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        Text(
                          'Order Terbaru',
                          style: AppTextStyles.labelLg.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                        const Spacer(),
                        // Plain tap target — no Material ripple, no hover
                        // highlight, so the link reads as inline secondary
                        // text rather than a button.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push('/orders'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Lihat Semua',
                              style: AppTextStyles.labelLg.copyWith(color: AppColors.secondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  ordersAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error: $e', style: TextStyle(color: context.colors.error)),
                    ),
                    data: (orders) {
                      if (orders.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'Belum ada order aktif',
                              style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
                            ),
                          ),
                        );
                      }
                      final latest = orders.take(5).toList();
                      return Padding(
                        // 8px top so the first card breathes below the
                        // "Order Terbaru" header row (which has 0 bottom
                        // padding — it sits flush to the divider).
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          children: latest.map((o) {
                            // Use the same card as the Daftar Order list
                            // so the "Order Terbaru" row visually anchors
                            // to the dedicated Orders tab. Falls back to
                            // a 3-line layout when the order has no items.
                            final segments = o.items.isNotEmpty
                                ? buildOrderSegments(o.items.first)
                                : const <OrderSummarySegment>[];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: OrderSummaryCard(
                                ticketNumber: '#${o.ticketNumber}',
                                customerName: o.customerName ?? '-',
                                status: OrderStatusX.fromString(o.status),
                                totalLabel: NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(o.total),
                                segments: segments,
                                createdAt: o.createdAt,
                                onTap: () => context.push('/orders/${o.id}'),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/orders/create'),
        // DESIGN.md FAB: secondaryContainer bg + onSecondaryContainer icon.
        backgroundColor: AppColors.secondaryContainer,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, color: AppColors.onSecondaryContainer, size: 28),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: TextStyle(color: context.colors.error))),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}