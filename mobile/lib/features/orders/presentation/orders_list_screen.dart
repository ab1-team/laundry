import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_tab_header.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/order_summary_card.dart';
import '../../../core/widgets/status_chip.dart';
import 'orders_provider.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  String _group = 'all'; // all | active | history | diambil | unpaid
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor: context.colors.surface,
          systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarDividerColor: context.colors.surface,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Column(
          children: [
            AppTabHeader(
              onTrailingTap: () => context.push('/settings'),
            ),

            Expanded(
              child: Column(
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: AppTextField(
                      label: '',
                      hint: 'Cari nama atau no. nota...',
                      controller: _searchCtrl,
                      prefixIcon: Icons.search,
                      variant: AppTextFieldVariant.search,
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),

                  // Filter chips — SizedBox is 72 (16 top + 40 chip + 16 bottom) so the
                  // labelLg pill (40px tall) never gets clipped by the box.
                  SizedBox(
                    height: 72,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          _FilterChip(label: 'Semua', selected: _group == 'all', onTap: () => setState(() => _group = 'all')),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Aktif', selected: _group == 'active', onTap: () => setState(() => _group = 'active')),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Selesai', selected: _group == 'history', onTap: () => setState(() => _group = 'history')),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Diambil', selected: _group == 'diambil', onTap: () => setState(() => _group = 'diambil')),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Belum Lunas', selected: _group == 'unpaid', onTap: () => setState(() => _group = 'unpaid')),
                        ],
                      ),
                    ),
                  ),

                  // List
                  Expanded(child: _buildList()),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/orders/create'),
        backgroundColor: AppColors.secondaryContainer,
        foregroundColor: AppColors.onSecondaryContainer,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildList() {
    final repo = ref.read(orderRepositoryProvider);
    final query = <String, dynamic>{};
    if (_group == 'active' || _group == 'history') query['group'] = _group;
    if (_group == 'diambil') query['status'] = 'diambil';
    if (_search.isNotEmpty) query['search'] = _search;

    // "Belum Lunas" filter is computed server-side via ?unpaid=1 (SQL
    // subquery against payments), so the result survives Laravel's
    // paginate(20) — first page is already representative of all
    // outstanding orders without scanning the whole active list.
    // We deliberately do NOT pair it with `group: 'active'`: an unpaid
    // order can be in any pipeline state (e.g. `diambil` but not yet
    // settled). Sending `group=active` would hide those from the list.
    final isUnpaidFilter = _group == 'unpaid';

    return FutureBuilder(
      future: isUnpaidFilter
          ? repo.list(unpaid: true)
          : repo.list(
              status: query['status'] as String?,
              search: query['search'] as String?,
              group: query['group'] as String?,
            ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}', style: TextStyle(color: context.colors.error)));
        }
        final orders = snap.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Text(
              isUnpaidFilter ? 'Tidak ada order yang belum lunas' : 'Belum ada order',
              style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) {
              final o = orders[i];
              // Two-row middle band (qty + service) when the order has
              // items; falls back to a 3-line layout otherwise.
              final segments = o.items.isNotEmpty
                  ? buildOrderSegments(o.items, maxSegments: 1)
                  : const <OrderSummarySegment>[];
              return OrderSummaryCard(
                ticketNumber: '#${o.ticketNumber}',
                customerName: o.customerName ?? '-',
                status: OrderStatusX.fromString(o.status),
                totalLabel: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(o.total),
                segments: segments,
                createdAt: o.createdAt,
                onTap: () => context.push('/orders/${o.id}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // DESIGN.md filter tab: selected = primary pill, others = surfaceContainerHigh.
    final bg = selected ? AppColors.primary : context.colors.surfaceContainerHigh;
    final fg = selected ? AppColors.onPrimary : context.colors.onSurfaceVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Text(
            label,
            style: AppTextStyles.labelLg.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}