import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/payment_method_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/order_model.dart';
import 'orders_provider.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;

  static const _pipeline = [
    ('masuk', 'Masuk'),
    ('dicuci', 'Dicuci'),
    ('selesai', 'Selesai'),
    ('diambil', 'Diambil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateTime = DateFormat('d MMM y, HH:mm', 'id_ID');

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/orders'),
        ),
        title: orderAsync.maybeWhen(
          // Headline style matches design (headline-md-mobile, bold,
          // primary color) so the title reads as the screen anchor.
          data: (order) => Text(
            'Detail Order #${order.ticketNumber}',
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headlineMd.copyWith(
              fontSize: 20,
              // Reads from active scheme — Navy in light, Sky Blue in
              // dark — so the AppBar title stays visible on both modes.
              color: context.colors.primary,
            ),
          ),
          orElse: () => const Text('Detail Order'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: context.colors.error))),
        data: (order) {
          final currentIdx = _pipeline.indexWhere((p) => p.$1 == order.status);
          final next = currentIdx >= 0 && currentIdx < _pipeline.length - 1
              ? _pipeline[currentIdx + 1]
              : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Pipeline timeline + inline "Update Status" button.
              // Design groups them in one card so the stepper and the
              // primary action share a single visual container.
              _PipelineCard(
                currentIdx: currentIdx,
                next: next,
                orderId: order.id,
              ),
              const SizedBox(height: 12),

              // Customer card — same chrome as _CustomerRow in the
              // customer list (BorderRadius.summary, border + soft
              // shadow, 44px rounded-square avatar). Keeps the brand
              // consistent across screens; .design/ only sets the rough
              // shape and content, not the exact radius or avatar.
              Material(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.summary),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.summary),
                    border: Border.all(color: context.colors.surfaceContainerHighest, width: 1),
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
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Center(
                          child: Text(
                            (order.customerName ?? '?').substring(0, 1).toUpperCase(),
                            style: AppTextStyles.titleLg.copyWith(color: AppColors.secondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.customerName ?? '-', style: AppTextStyles.titleLg),
                            const SizedBox(height: 4),
                            Text(
                              order.customerPhone ?? '-',
                              style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rincian Layanan
              _SectionTitleRow(label: 'RINCIAN LAYANAN', trailing: Icons.info_outline),
              const SizedBox(height: 8),
              _CardContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ...order.items.map((it) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.serviceName,
                                      style: AppTextStyles.bodyLg,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${it.qty} ${it.unit} × ${rupiah.format(it.price)}',
                                      style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Text(rupiah.format(it.subtotal), style: AppTextStyles.titleLg),
                            ],
                          ),
                        )),
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: context.colors.outlineVariant, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text('Total Harga', style: AppTextStyles.labelLg),
                          const Spacer(),
                          Text(
                            rupiah.format(order.total),
                            style: AppTextStyles.headlineMd.copyWith(
                              fontSize: 20,
                              color: context.colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pembayaran — distinct surface so the user reads it as a
              // separate concern from the service line items.
              _SectionTitleRow(
                label: 'INFORMASI PEMBAYARAN',
                leadingIcon: Icons.payments_outlined,
                leadingColor: AppColors.secondary,
                labelColor: AppColors.secondary,
              ),
              const SizedBox(height: 8),
              _CardContainer(
                padding: const EdgeInsets.all(20),
                background: context.colors.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DIBAYAR',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(rupiah.format(order.totalPaid), style: AppTextStyles.titleLg),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SISA TAGIHAN',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rupiah.format(order.remaining),
                                style: AppTextStyles.titleLg.copyWith(
                                  color: order.remaining > 0 ? context.colors.error : context.colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (order.remaining > 0)
                      // Bayar / Lunasi — only when there's still an
                      // outstanding balance. Opens a bottom sheet so the
                      // operator can enter the partial amount and method.
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () => _openPayOrderSheet(context, ref, order: order),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.onSecondary,
                            textStyle: AppTextStyles.labelLg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                          // Text first, icon on the trailing edge to
                          // match the "Update Status" button styling.
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Bayar — ${rupiah.format(order.remaining)}'),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.statusSelesai,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lunas pada ${dateTime.format(order.finishedAt ?? order.pickedUpAt ?? order.createdAt)}',
                              style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Riwayat Pesanan timeline
              _SectionTitleRow(label: 'RIWAYAT PESANAN'),
              const SizedBox(height: 8),
              _CardContainer(
                padding: const EdgeInsets.all(20),
                child: _StatusTimeline(logs: order.statusLogs, dateTime: dateTime),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.logs, required this.dateTime});
  final List<OrderStatusLogModel> logs;
  final DateFormat dateTime;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Belum ada riwayat',
          style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
        ),
      );
    }
    // Show newest first so the most recent event sits at the top.
    final reversed = logs.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(reversed.length, (i) {
        final log = reversed[i];
        final isLast = i == reversed.length - 1;
        final isActive = i == 0;
        final dotColor = isActive ? AppColors.secondary : context.colors.outline;
        // Design `.design/detail_order`:
        //   rail: dot 8x8 (centre) + 1px connector full height
        //        using `surface-container-highest` (#EAE7EA)
        //   title: labelLg onSurface
        //   meta : bodyMd outline
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 16,
                child: Column(
                  // Center the dot within the row so it aligns with the
                  // title text baseline regardless of how tall the row
                  // becomes (e.g. when the subtitle wraps).
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: context.colors.surfaceContainerHighest,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${OrderStatusX.fromString(log.status).label}',
                        style: AppTextStyles.labelLg.copyWith(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.changedByName != null
                            ? '${dateTime.format(log.createdAt)} • Oleh: ${log.changedByName}'
                            : dateTime.format(log.createdAt),
                        style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.label,
    this.trailing,
    this.leadingIcon,
    this.leadingColor,
    this.labelColor,
  });
  final String label;
  final IconData? trailing;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18, color: leadingColor ?? context.colors.onSurfaceVariant),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.labelLg.copyWith(
              color: labelColor ?? context.colors.onSurfaceVariant,
            ),
          ),
        ),
        if (trailing != null)
          Icon(trailing, size: 18, color: context.colors.outline),
      ],
    );
  }
}

/// Card shell — same chrome as _CustomerRow / _CategoryRow across the
/// app: BorderRadius.summary, 1px surfaceContainerHigh border, soft
/// primary-tinted shadow. Centralised so each section gets identical
/// styling. A non-null [background] (e.g. surfaceContainerLow for the
/// payment info block) overrides the default surface white.
class _CardContainer extends StatelessWidget {
  const _CardContainer({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.background,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.summary),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: background ?? context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.summary),
          border: Border.all(color: context.colors.surfaceContainerHighest, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _PipelineCard extends ConsumerStatefulWidget {
  const _PipelineCard({
    required this.currentIdx,
    required this.next,
    required this.orderId,
  });

  final int currentIdx;
  // The next stage in the pipeline, or null when the order has reached
  // the terminal state (`diambil` or `dibatalkan`). When null, the
  // update button is hidden.
  final (String, String)? next;
  final int orderId;

  @override
  ConsumerState<_PipelineCard> createState() => _PipelineCardState();
}

class _PipelineCardState extends ConsumerState<_PipelineCard> {
  // Local loading flag — while true, the button shows a spinner and
  // ignores further taps. Resets on success or error.
  bool _updating = false;

  Future<void> _updateStatus() async {
    final next = widget.next;
    if (next == null || _updating) return;
    setState(() => _updating = true);
    try {
      await ref.read(orderRepositoryProvider).updateStatus(widget.orderId, next.$1);
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(activeOrdersProvider);
      ref.invalidate(historyOrdersProvider);
      if (mounted) {
        showAppSnackBar(
          context,
          'Status diupdate ke ${next.$2}',
          type: AppSnackBarType.success,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Gagal update: $e', type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = OrderDetailScreen._pipeline;
    final next = widget.next;
    // Stepper + update action share one card chrome so they read as a
    // single primary block (matches .design/detail_order line 139-177).
    return _CardContainer(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        children: [
          SizedBox(
            // The whole row shares one height so the connector line
            // passes exactly through the centre of each circle. The
            // line is drawn behind the circles via a Stack.
            height: 64,
            child: Stack(
              children: [
                // Background connector — runs the full width at the
                // vertical midpoint (32/2 from the top).
                Positioned(
                  top: 16,
                  left: 24,
                  right: 24,
                  child: Container(
                    height: 2,
                    color: context.colors.outlineVariant,
                  ),
                ),
                // Active connector — covers the segment from the left
                // edge to the centre of the active stage. As the order
                // advances, more of the line is painted secondary.
                Positioned(
                  top: 16,
                  left: 24,
                  child: FractionallySizedBox(
                    widthFactor: widget.currentIdx < 0
                        ? 0
                        : widget.currentIdx / (stages.length - 1),
                    child: Container(
                      height: 2,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                // Stage markers — distributed evenly so they line up
                // with the connector endpoints.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(stages.length, (i) {
                    final stage = stages[i];
                    final passed = widget.currentIdx >= i;
                    final active = widget.currentIdx == i;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: passed
                                ? AppColors.secondary
                                : context.colors.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            passed ? Icons.check : _iconFor(stage.$1),
                            color: passed
                                ? AppColors.onSecondary
                                : context.colors.onSurfaceVariant,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stage.$2,
                          style: AppTextStyles.labelSm.copyWith(
                            color: active
                                ? AppColors.secondary
                                : context.colors.onSurfaceVariant,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _updating ? null : _updateStatus,
                // Manual Row so we can match design order: text first,
                // then icon on the trailing edge (FilledButton.icon
                // always renders icon-first).
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: AppColors.onPrimary,
                  textStyle: AppTextStyles.labelLg.copyWith(fontSize: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                // Spinner replaces the trailing arrow while the request
                // is in flight — gives the operator a visible "we're
                // working" cue without disabling the whole UI.
                child: _updating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Update Status ke ${next.$2}'),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String stage) {
    switch (stage) {
      case 'masuk':   return Icons.shopping_bag_outlined;
      case 'dicuci':  return Icons.local_laundry_service_outlined;
      case 'selesai': return Icons.check_circle_outline;
      case 'diambil': return Icons.inventory_2_outlined;
      default:        return Icons.circle;
    }
  }
}

// ===========================================
// Pay / lunasi sheet
// ===========================================

/// Open a bottom sheet so the operator can record a payment against
/// an existing order (DP follow-up, hutang payoff, or partial top-up).
Future<void> _openPayOrderSheet(
  BuildContext context,
  WidgetRef ref, {
  required OrderModel order,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PayOrderSheet(order: order),
  );
}

class _PayOrderSheet extends ConsumerStatefulWidget {
  const _PayOrderSheet({required this.order});
  final OrderModel order;

  @override
  ConsumerState<_PayOrderSheet> createState() => _PayOrderSheetState();
}

class _PayOrderSheetState extends ConsumerState<_PayOrderSheet> {
  // Default to the full remaining balance so the operator can just
  // confirm in the common "lunasi sekarang" case. Editable to support
  // arbitrary partial payments.
  late final TextEditingController _amount;
  String _method = 'cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController();
    _amount.text = widget.order.remaining
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    _amount.selection =
        TextSelection.collapsed(offset: _amount.text.length);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _amount.text.replaceAll('.', '');
    final amount = double.tryParse(raw) ?? 0;
    if (amount <= 0) {
      showAppSnackBar(context, 'Nominal pembayaran wajib diisi', type: AppSnackBarType.error);
      return;
    }
    if (amount > widget.order.remaining) {
      showAppSnackBar(context, 'Nominal melebihi sisa tagihan', type: AppSnackBarType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(orderRepositoryProvider).recordPayment(
            widget.order.id,
            amount: amount,
            method: _method,
          );
      if (mounted) {
        ref.invalidate(orderDetailProvider(widget.order.id));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(context, 'Gagal: $e', type: AppSnackBarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final rupiah = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.colors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Catat Pembayaran',
                      style: AppTextStyles.titleLg,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Sisa tagihan: ${rupiah.format(widget.order.remaining)}',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Amount field with thousands separator via the
                      // currency variant — same UX as the DP input on
                      // create-order.
                      _CurrencyInput(controller: _amount),
                      const SizedBox(height: 16),
                      Text('Metode', style: AppTextStyles.labelLg),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          PaymentMethodCard(
                            label: 'Cash',
                            icon: Icons.payments_outlined,
                            selected: _method == 'cash',
                            onTap: () => setState(() => _method = 'cash'),
                          ),
                          const SizedBox(width: 8),
                          PaymentMethodCard(
                            label: 'Transfer',
                            icon: Icons.account_balance_outlined,
                            selected: _method == 'transfer',
                            onTap: () => setState(() => _method = 'transfer'),
                          ),
                          const SizedBox(width: 8),
                          PaymentMethodCard(
                            label: 'QRIS',
                            icon: Icons.qr_code_2_outlined,
                            selected: _method == 'qris',
                            onTap: () => setState(() => _method = 'qris'),
                            disabled: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                        child: Text(_saving ? 'Menyimpan...' : 'Simpan Pembayaran'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thousand-separator input without the "Rp" prefix (the sheet already
/// shows the remaining balance above the field, so the prefix would
/// be redundant). Re-uses the same formatter logic as the currency
/// variant of `AppTextField` — kept inline here so we don't widen the
/// shared widget's API just for this screen.
class _CurrencyInput extends StatelessWidget {
  const _CurrencyInput({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      style: AppTextStyles.bodyLg,
      inputFormatters: [_ThousandsOnlyFormatter()],
      decoration: InputDecoration(
        labelText: 'Nominal',
        hintText: '0',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: context.colors.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: context.colors.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
      ),
    );
  }
}

class _ThousandsOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
