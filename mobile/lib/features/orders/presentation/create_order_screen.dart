import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/payment_method_card.dart';
import '../../master/data/service.dart';
import '../../master/data/service_category.dart';
import '../../master/presentation/master_provider.dart';
import '../../customers/presentation/customers_provider.dart';
import 'orders_provider.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

/// Cap the number of customer search results rendered inline in the
/// Buat Order form. Backend pagination returns up to 20; we trim to 5
/// so the picker stays scannable, and hint the user to refine the
/// search if there are more matches.
const int _kCustomerSearchLimit = 5;

class _LineItem {
  _LineItem({
    required this.serviceId,
    required this.categoryId,
    required this.categoryName,
    required this.categorySortOrder,
    required this.name,
    required this.unit,
    required this.categoryIconUrl,
    required this.price,
  }) : qty = 1;
  final int serviceId;
  final int categoryId;
  // Cached category metadata so the Layanan section can group rows by
  // category + render headers without re-watching categoriesProvider —
  // the picker already passes these in when constructing the line.
  final String categoryName;
  final int categorySortOrder;
  final String name;
  final String unit;
  final String? categoryIconUrl;
  final double price;
  // Mutable: stepper buttons mutate `qty` directly on the line.
  // ignore: prefer_final_fields
  double qty;
  double get subtotal => price * qty;
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  int? _customerId;
  String? _customerName;
  // Selected line items; each entry is a service the operator picked from
  // the picker dialog, with its own qty. Order = display order under Layanan.
  final List<_LineItem> _items = [];
  // O(1) "is this service currently in _items?" lookup, mirrors _items keys.
  final Set<int> _checkedServiceIds = <int>{};
  String _payment = 'lunas'; // lunas | dp | hutang
  String _method = 'cash';
  final _notesCtrl = TextEditingController();
  // DP amount (uang muka). Only used when _payment == 'dp'. Edited via
  // the inline input that appears under the segmented control.
  final _dpCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Rebuild the "sisa" hint under the DP field as the operator types.
    _dpCtrl.addListener(() => setState(() {}));
  }

  // Customer search — debounced query against /customers?search=.
  String _customerSearch = '';
  List<Map<String, dynamic>> _customerResults = const [];
  bool _searchingCustomer = false;
  Timer? _searchDebounce;

  // Snapshot of the last search so clicking "x" on a picked customer
  // restores the prior picker state instead of leaving the input
  // empty (or, worse, with a stale query).
  final _searchCtrl = TextEditingController();
  String? _lastSearchTerm;
  List<Map<String, dynamic>>? _lastSearchResults;

  double get _total => _subtotal;

  /// Sum of all selected line-item subtotals. Bound to the bottom
  /// "Total Tagihan" row and to the DP validation upper bound.
  double get _subtotal =>
      _items.fold<double>(0, (acc, i) => acc + i.subtotal);

  /// Remove a selected service line (called from the Layanan summary row's
  /// "Hapus" button). Mirrors the toggle-off branch that used to live in
  /// the old inline Layanan list — `_items` and `_checkedServiceIds` are
  /// kept in sync so no future caller has to remember to update both.
  void _removeService(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      _checkedServiceIds.remove(removed.serviceId);
    });
  }

  void _incrementQty(int index) {
    setState(() {
      final next = _items[index].qty + 0.5;
      _items[index].qty = next.clamp(0.5, 999).toDouble();
    });
  }

  void _decrementQty(int index) {
    setState(() {
      final next = _items[index].qty - 0.5;
      _items[index].qty = next < 0.5 ? 0.5 : next.toDouble();
    });
  }

  /// Open the centered service picker dialog. Multi-add: tapping a row
  /// pops the dialog with the picked Service, the parent inserts the line,
  /// then re-opens the dialog so the operator can keep adding until they
  /// dismiss it manually (close icon / barrier tap).
  ///
  /// No-op while services or categories are still loading — the search
  /// field is rendered with `onTap: null` in that state via the parent's
  /// build, but guard here too in case the user manages to trigger it.
  Future<void> _openServicePicker() async {
    final services = ref.read(servicesProvider).value;
    final categories = ref.read(categoriesProvider).value;
    if (services == null || categories == null) return;

    final picked = await showDialog<Service>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ServicePickerDialog(
        services: services,
        categories: categories,
        excludeIds: _checkedServiceIds,
      ),
    );
    if (!mounted || picked == null) return;
    // Resolve category metadata once at insert time so the Layanan
    // section can group rows + render headers without re-watching
    // categoriesProvider on every rebuild.
    final cat = categories.firstWhere(
      (c) => c.id == picked.categoryId,
      orElse: () => ServiceCategory(
        id: picked.categoryId,
        name: picked.categoryName ?? 'Kategori',
        sortOrder: 9999,
      ),
    );
    setState(() {
      _items.add(_LineItem(
        serviceId: picked.id,
        categoryId: picked.categoryId,
        categoryName: cat.name,
        categorySortOrder: cat.sortOrder,
        name: picked.name,
        unit: picked.unit,
        categoryIconUrl: picked.effectiveIconUrl,
        price: picked.price,
      ));
      _checkedServiceIds.add(picked.id);
    });
    // Re-open so the operator can keep building the order without an
    // extra tap. The freshly-picked service is now in `excludeIds` so the
    // list re-filters automatically. Recursion bottoms out when the user
    // dismisses the dialog manually (returns null).
    await _openServicePicker();
  }

  Future<void> _runCustomerSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _customerResults = const []);
      return;
    }
    setState(() => _searchingCustomer = true);
    try {
      final res = await ApiClient.instance.dio.get('/customers', queryParameters: {
        'search': query.trim(),
      });
      final data = ((res.data as Map)['data'] as List).cast<Map<String, dynamic>>();
      // Auto-pick when the search resolves to exactly one match — saves
      // a tap when the user already knows the customer's full name or
      // phone. The "x" button on the picked card restores the picker.
      // Keep the query in the search field so the user can see what
      // was matched; only clear the results list since there's nothing
      // left to choose from.
      if (data.length == 1 && mounted && _customerId == null) {
        final only = data.first;
        // Snapshot so the user can still back out via the "x" button.
        _lastSearchTerm = query;
        _lastSearchResults = List.of(data);
        setState(() {
          _customerId = only['id'] as int;
          _customerName = only['name'] as String;
          // Clear the picker state too — otherwise the build method sees
          // "_customerSearch non-empty + _customerResults empty" and
          // flashes a misleading "Tidak ada hasil" message below the
          // already-picked card.
          _customerSearch = '';
          _customerResults = const [];
          _searchCtrl.clear();
        });
        return;
      }
      if (mounted) setState(() => _customerResults = data);
    } catch (_) {
      if (mounted) setState(() => _customerResults = const []);
    } finally {
      if (mounted) setState(() => _searchingCustomer = false);
    }
  }

  void _onCustomerSearchChanged(String v) {
    // Typing in the search field after a pick implicitly means the user
    // wants a different customer — drop the pick so the new search can
    // drive the picker cleanly (auto-pick, list, or empty state).
    if (_customerId != null && v.isNotEmpty) {
      _customerId = null;
      _customerName = null;
    }
    _customerSearch = v;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _runCustomerSearch(v));
  }

  void _pickCustomer(Map<String, dynamic> c) {
    // Snapshot the current search context so the "x" button can
    // restore it after the user reconsiders.
    _lastSearchTerm = _customerSearch;
    _lastSearchResults = List.of(_customerResults);
    setState(() {
      _customerId = c['id'] as int;
      _customerName = c['name'] as String;
      _customerSearch = '';
      _customerResults = const [];
    });
  }

  void _clearPickedCustomer() {
    setState(() {
      _customerId = null;
      _customerName = null;
      // Restore the search field + results from the moment of pick,
      // so the user lands back on the same picker view they left.
      if (_lastSearchTerm != null) {
        _customerSearch = _lastSearchTerm!;
        _customerResults = _lastSearchResults ?? const [];
        _searchCtrl.text = _lastSearchTerm!;
        _searchCtrl.selection =
            TextSelection.collapsed(offset: _lastSearchTerm!.length);
      }
      _lastSearchTerm = null;
      _lastSearchResults = null;
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _dpCtrl.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final categoriesAsync = ref.watch(categoriesProvider);
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/orders'),
        ),
        title: const Text('Buat Order Baru'),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Customer — DESIGN.md section title: title-lg primary.
          Text('Pilih Customer', style: AppTextStyles.titleLg.copyWith(color: context.colors.primary)),
          const SizedBox(height: 8),
          // Search field + Add button as two sibling widgets so they
          // sit side-by-side at the same height (the search bar's 48px).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppTextField(
                  label: '',
                  hint: 'Cari nama atau nomor HP...',
                  prefixIcon: Icons.search,
                  variant: AppTextFieldVariant.search,
                  controller: _searchCtrl,
                  onChanged: _onCustomerSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: TextButton.icon(
                  onPressed: _openAddCustomerSheet,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Tambah'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onSecondaryContainer,
                    backgroundColor: AppColors.secondaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
              ),
            ],
          ),
          // Search results — inline under the search field. Always
          // visible (when there's a query in flight) so users can
          // refine or switch picks even after one is already active.
          // The picked-card just sits below the list.
          if (_searchingCustomer)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
              ),
            )
          else if (_customerResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Cap inline results so the list never outgrows the viewport;
            // the rest can still be reached by refining the search.
            ..._customerResults
                .take(_kCustomerSearchLimit)
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CustomerSearchResult(
                        name: c['name'] as String,
                        phone: c['phone'] as String?,
                        onTap: () => _pickCustomer(c),
                      ),
                    )),
            if (_customerResults.length > _kCustomerSearchLimit)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Menampilkan $_kCustomerSearchLimit hasil teratas — ketik lebih spesifik untuk mempersempit.',
                  style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
          ] else if (_customerSearch.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada hasil',
                style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          if (_customerId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_customerName ?? '', style: AppTextStyles.bodyLg)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clearPickedCustomer,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text('Layanan', style: AppTextStyles.titleLg.copyWith(color: context.colors.primary)),
          const SizedBox(height: 8),
          // Search field as a tappable trigger into the picker dialog.
          // We don't filter in place anymore — Layanan only shows selected
          // services, and adding more happens inside the centered picker
          // (multi-add). The field is rendered inside a Material+InkWell
          // so the whole bar gets the search-bar ripple + a single tap
          // target. While services are loading, replace the InkWell
          // with a spinner (centered) so the user sees why taps are inert.
          SizedBox(
            height: 48,
            child: Stack(
              children: [
                // Underlying visual: the AppTextField (decoration only —
                // it's disabled and ignores input). Sits at z=0 so the
                // InkWell above can paint its ripple on top.
                IgnorePointer(
                  child: Opacity(
                    opacity: servicesAsync.value == null ? 0.4 : 1.0,
                    child: AppTextField(
                      label: '',
                      hint: 'Cari atau pilih layanan...',
                      prefixIcon: Icons.search,
                      variant: AppTextFieldVariant.search,
                      // No controller: the field is purely decorative.
                      // We don't want user typing to drive any state.
                      enabled: false,
                    ),
                  ),
                ),
                if (servicesAsync.value == null)
                  const Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        onTap: _openServicePicker,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Body: empty-state card when nothing picked, otherwise the
          // summary header + selected-lines list.
          if (_items.isEmpty)
            _EmptyLayananCard(onTap: _openServicePicker)
          else ...[
            _LayananSummary(count: _items.length, total: _subtotal),
            const SizedBox(height: 12),
            // Group lines by category so each category gets its own
            // header above its tiles (mirrors the picker dialog grouping).
            // Group order matches master-data sortOrder; within a group
            // we preserve the order the operator picked services in
            // (no extra sort — picked order == display order).
            ..._buildGroupedLineRows(),
          ],
          // Surface load errors inline so the user knows why the picker
          // is unusable. The search bar above silently swallows taps in
          // error state, so the message is what needs their attention.
          servicesAsync.maybeWhen(
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Gagal memuat layanan: $e',
                style: AppTextStyles.bodyMd.copyWith(color: context.colors.error),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          categoriesAsync.maybeWhen(
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Gagal memuat kategori: $e',
                style: AppTextStyles.bodyMd.copyWith(color: context.colors.error),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: 20),
          AppTextField(
            label: 'Catatan',
            hint: 'Opsional',
            controller: _notesCtrl,
            maxLines: 3,
          ),

          const SizedBox(height: 20),
          Text('Pembayaran', style: AppTextStyles.titleLg.copyWith(color: context.colors.primary)),
          const SizedBox(height: 8),
          // DESIGN.md payment status: segmented control with surface-container-high
          // track and white floating selected tab. _PayChip is the inner button;
          // the Container here is the pill track.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: [
                Expanded(child: _PayChip(label: 'Lunas',  selected: _payment == 'lunas',  onTap: () => setState(() => _payment = 'lunas'))),
                const SizedBox(width: 4),
                Expanded(child: _PayChip(label: 'DP',     selected: _payment == 'dp',     onTap: () => setState(() => _payment = 'dp'))),
                const SizedBox(width: 4),
                Expanded(child: _PayChip(label: 'Hutang', selected: _payment == 'hutang', onTap: () => setState(() => _payment = 'hutang'))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_payment == 'dp') ...[
            // DP amount input. Use the currency variant so the operator
            // gets the Rp prefix and thousands grouping for free.
            AppTextField(
              label: 'Nominal DP',
              hint: '0',
              controller: _dpCtrl,
              variant: AppTextFieldVariant.currency,
            ),
            const SizedBox(height: 8),
            Text(
              'Sisa: ${rupiah.format(_total - (double.tryParse(_dpCtrl.text.replaceAll('.', '')) ?? 0))}',
              style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              PaymentMethodCard(label: 'Cash',     icon: Icons.payments_outlined,         selected: _method == 'cash',     onTap: () => setState(() => _method = 'cash')),
              const SizedBox(width: 8),
              PaymentMethodCard(label: 'Transfer', icon: Icons.account_balance_outlined,  selected: _method == 'transfer', onTap: () => setState(() => _method = 'transfer')),
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

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text('Total Tagihan', style: AppTextStyles.bodyLg.copyWith(color: context.colors.onSurfaceVariant)),
                const Spacer(),
                Text(
                  rupiah.format(_total),
                  style: AppTextStyles.headlineMd.copyWith(color: context.colors.primary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // DESIGN.md submit button: full width, large padding, primary pill.
          SizedBox(
            height: 56,
            child: AppButton(
              label: 'Simpan Order',
              onPressed: _canSubmit ? _submit : null,
              loading: _submitting,
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSubmit =>
      _customerId != null &&
      _items.isNotEmpty &&
      _items.every((i) => i.qty > 0);

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final order = await repo.create(
        customerId: _customerId!,
        items: _items
            .map((i) => (serviceId: i.serviceId, qty: i.qty))
            .toList(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      // Record the first payment inline so the order lands in the
      // correct state without forcing the operator to open it again.
      //   lunas  → full amount = _total
      //   dp     → partial amount typed in by the operator
      //   hutang → none; remaining = total, recorded later
      double? paidAmount;
      if (_payment == 'lunas') {
        paidAmount = _total;
      } else if (_payment == 'dp') {
        // Strip the thousands separator we render via _ThousandsSeparatorFormatter.
        paidAmount = double.tryParse(_dpCtrl.text.replaceAll('.', '')) ?? 0;
        if (paidAmount <= 0 || paidAmount > _total) {
          throw Exception(
            paidAmount <= 0
                ? 'Nominal DP belum diisi'
                : 'Nominal DP melebihi total tagihan',
          );
        }
      }

      if (paidAmount != null) {
        await repo.recordPayment(
          order.id,
          amount: paidAmount,
          method: _method,
        );
      }

      ref.invalidate(activeOrdersProvider);
      ref.invalidate(historyOrdersProvider);
      if (mounted) {
        context.go('/orders/${order.id}');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Gagal: $e', type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openAddCustomerSheet() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCustomerSheet(),
    );
    if (created != null && mounted) _pickCustomer(created);
  }

  /// Render the selected-lines list as a flat sequence of widgets
  /// grouped by category. Each group starts with a `_LayananCategoryHeader`
  /// followed by the line rows for that category. Returns an empty list
  /// when `_items` is empty (defensive — caller already gates on
  /// `_items.isEmpty`, but keeps this idempotent).
  ///
  /// Group order matches the master-data `sortOrder` (set by the tenant
  /// owner), so the visual order of category sections is stable across
  /// picks. Within a group, lines appear in pick order (FIFO) — no
  /// secondary sort, since the operator's pick order is the natural
  /// display order for an order under construction.
  List<Widget> _buildGroupedLineRows() {
    final byCat = <int, List<int>>{};
    for (var i = 0; i < _items.length; i++) {
      byCat.putIfAbsent(_items[i].categoryId, () => <int>[]).add(i);
    }
    final catIds = byCat.keys.toList()
      ..sort((a, b) {
        final ao = _items.firstWhere((it) => it.categoryId == a).categorySortOrder;
        final bo = _items.firstWhere((it) => it.categoryId == b).categorySortOrder;
        if (ao != bo) return ao.compareTo(bo);
        // Tie-break by name for deterministic order when two categories
        // share a sort_order.
        final an = _items.firstWhere((it) => it.categoryId == a).categoryName;
        final bn = _items.firstWhere((it) => it.categoryId == b).categoryName;
        return an.compareTo(bn);
      });
    final widgets = <Widget>[];
    for (final catId in catIds) {
      final indices = byCat[catId]!;
      final sample = _items[indices.first];
      widgets.add(_LayananCategoryHeader(
        name: sample.categoryName,
        iconUrl: sample.categoryIconUrl,
      ));
      widgets.add(const SizedBox(height: 8));
      for (var k = 0; k < indices.length; k++) {
        widgets.add(_buildSelectedLineRow(indices[k]));
        if (k < indices.length - 1) {
          widgets.add(const SizedBox(height: 8));
        }
      }
      widgets.add(const SizedBox(height: 16));
    }
    // Drop the trailing gap after the last group so the bottom doesn't
    // get a stray 16px before the next section.
    if (widgets.isNotEmpty) widgets.removeLast();
    return widgets;
  }

  Widget _buildSelectedLineRow(int index) {
    final item = _items[index];
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.colors.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: thumbnail + name + price/unit on the left,
            // compact qty stepper on the right.
            Row(
              children: [
                _OrderCategoryIcon(
                  iconUrl: item.categoryIconUrl,
                  size: 36,
                  rounded: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTextStyles.bodyLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rupiah.format(item.price)} / ${item.unit}',
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _MiniStepperBtn(
                  icon: Icons.remove,
                  onTap: () => _decrementQty(index),
                  onPrimary: false,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    item.qty.toStringAsFixed(1),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                _MiniStepperBtn(
                  icon: Icons.add,
                  onTap: () => _incrementQty(index),
                  onPrimary: false,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Bottom row: subtotal + Hapus button. Separated from the
            // top row by a thin divider so the destructive action reads
            // as a discrete affordance rather than blending into the
            // stepper controls.
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Subtotal ${rupiah.format(item.subtotal)}',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _removeService(index),
                  icon: Icon(Icons.delete_outline, size: 16, color: context.colors.error),
                  label: Text(
                    'Hapus',
                    style: AppTextStyles.labelLg.copyWith(color: context.colors.error),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    // DESIGN.md service pill: selected = filled secondary + 2px secondary border;
    // unselected = white surface + 2px outline-variant border.
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.secondary : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: selected ? AppColors.secondary : context.colors.outlineVariant,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              label,
              style: AppTextStyles.labelLg.copyWith(
                color: selected ? AppColors.onSecondary : context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Compact 32x32 stepper button. `onPrimary: true` (default) tints white-on-primary
// for use against the old primary-fill selected row background. Pass
// `onPrimary: false` to render on a neutral surface (secondaryContainer fill
// + secondary icon) — used inside the Layanan summary rows which sit on a
// plain surface background.
class _MiniStepperBtn extends StatelessWidget {
  const _MiniStepperBtn({
    required this.icon,
    required this.onTap,
    this.onPrimary = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool onPrimary;
  @override
  Widget build(BuildContext context) {
    final bg = onPrimary
        ? AppColors.onPrimary.withValues(alpha: 0.18)
        : AppColors.secondaryContainer;
    final fg = onPrimary ? AppColors.onPrimary : AppColors.secondary;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, color: fg, size: 18),
        ),
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  const _PayChip({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    // DESIGN.md segmented tab: track is a single surfaceContainerHigh pill
    // (rendered by the parent Row). This widget is just the inner button —
    // selected = white floating tab w/ shadow + primary text; unselected =
    // transparent track w/ onSurfaceVariant text.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? context.colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelLg.copyWith(
                  color: selected ? context.colors.primary : context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================
// Customer search result row
// ===========================================

class _CustomerSearchResult extends StatelessWidget {
  const _CustomerSearchResult({
    required this.name,
    required this.phone,
    required this.onTap,
  });

  final String name;
  final String? phone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: context.colors.surfaceContainerHighest, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: AppTextStyles.titleLg.copyWith(color: AppColors.secondary, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.bodyLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (phone != null && phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(phone!, style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================
// Add Customer sheet (bottom sheet, pinned header)
// ===========================================

class _AddCustomerSheet extends ConsumerStatefulWidget {
  const _AddCustomerSheet();

  @override
  ConsumerState<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends ConsumerState<_AddCustomerSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController(text: '628');
    _phone.selection = TextSelection.collapsed(offset: _phone.text.length);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
      final created = await repo.create(
        name: _name.text.trim(),
        phone: phone,
      );
      if (mounted) {
        Navigator.pop(context, {
          'id': created.id,
          'name': created.name,
        });
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
                      'Tambah Customer',
                      style: AppTextStyles.titleLg,
                      textAlign: TextAlign.center,
                    ),
                  ],
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
                      AppTextField(
                        label: 'Nama',
                        hint: 'Contoh: Budi Santoso',
                        controller: _name,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Nomor HP',
                        hint: '12345678...',
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                        ),
                        child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
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

// ===========================================
// Empty-state card for the Layanan section
// ===========================================

/// Outlined CTA card shown when no service has been picked yet. Whole card
/// is tappable so the user has a large, obvious target to open the picker.
class _EmptyLayananCard extends StatelessWidget {
  const _EmptyLayananCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.input),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: context.colors.outlineVariant, width: 1),
          ),
          child: Column(
            children: [
              Icon(
                Icons.local_laundry_service_outlined,
                size: 32,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Belum ada layanan dipilih',
                style: AppTextStyles.bodyLg,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap untuk memilih',
                style: AppTextStyles.bodyMd.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================
// Layanan summary header (count + subtotal)
// ===========================================

/// Compact header above the selected-lines list. Shows total item count
/// on the left and the running subtotal on the right so the user can see
/// at a glance how the order is shaping up before reaching the bottom
/// "Total Tagihan" row.
class _LayananSummary extends StatelessWidget {
  const _LayananSummary({required this.count, required this.total});
  final int count;
  final double total;
  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '$count layanan',
              style: AppTextStyles.bodyMd.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              rupiah.format(total),
              style: AppTextStyles.titleLg.copyWith(color: context.colors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}

/// Per-category section header used inside the Layanan summary list.
/// Mirrors the picker dialog's `_PickerCategoryHeader` so the operator's
/// eye scans it the same way in both places — tiny category icon +
/// uppercase tracking-wide label. Always rendered (no "Semua" mode to
/// skip) because by the time we're in this list the user has already
/// chosen which services they want; the header just labels the bucket.
class _LayananCategoryHeader extends StatelessWidget {
  const _LayananCategoryHeader({required this.name, this.iconUrl});
  final String name;
  final String? iconUrl;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          _OrderCategoryIcon(iconUrl: iconUrl, size: 18),
          const SizedBox(width: 6),
          Text(
            name,
            style: AppTextStyles.labelSm.copyWith(
              color: context.colors.outline,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================
// Service picker dialog (multi-add)
// ===========================================

/// Centered modal picker for adding services to an order.
///
/// Multi-add semantics: tapping a row pops the dialog with the picked
/// [Service]; the parent screen inserts it into `_items` and re-opens
/// the dialog so the operator can keep selecting without an extra tap.
/// The freshly-picked service is in `excludeIds` so the list re-filters
/// automatically on re-open. Cancel by tapping the close icon or the
/// barrier (returns null → parent does NOT re-open).
///
/// `excludeIds` is the set of service ids already in the order; matching
/// services are hidden from the picker list entirely.
class _ServicePickerDialog extends StatefulWidget {
  const _ServicePickerDialog({
    required this.services,
    required this.categories,
    required this.excludeIds,
  });
  final List<Service> services;
  final List<ServiceCategory> categories;
  final Set<int> excludeIds;

  @override
  State<_ServicePickerDialog> createState() => _ServicePickerDialogState();
}

class _ServicePickerDialogState extends State<_ServicePickerDialog> {
  // `null` = "Semua". Moved here from the parent screen so the picker's
  // filter state is fully self-contained and resets on every open.
  int? _categoryFilterId;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (_search != _searchCtrl.text) {
        setState(() => _search = _searchCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onPick(Service s) {
    // Return the picked service to the parent via Navigator.pop. The
    // parent handles the actual insertion + auto re-open.
    Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    // Lookup table for category metadata (sortOrder + name + iconUrl).
    final catsById = {for (final c in widget.categories) c.id: c};
    final filtered = widget.services.where((s) {
      if (widget.excludeIds.contains(s.id)) return false;
      if (_categoryFilterId != null && s.categoryId != _categoryFilterId) return false;
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    // Group by categoryId so we can render per-category section headers
    // inside the scrollable list. Groups preserve the master-data order:
    // Map iteration is insertion order, and we insert categories in
    // sortOrder-then-name order, so the headers match the pill row
    // above and the picker order the owner set in Master Data.
    final groups = <int, List<Service>>{};
    for (final s in filtered) {
      groups.putIfAbsent(s.categoryId, () => <Service>[]).add(s);
    }
    final sortedCategoryIds = groups.keys.toList()
      ..sort((a, b) {
        final ao = catsById[a]?.sortOrder ?? 9999;
        final bo = catsById[b]?.sortOrder ?? 9999;
        if (ao != bo) return ao.compareTo(bo);
        // Tie-break by name so equal sort_order values get a deterministic
        // (alphabetical) ordering.
        return (catsById[a]?.name ?? '').compareTo(catsById[b]?.name ?? '');
      });
    // Within each group, alphabetical by service name.
    for (final list in groups.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    // Three distinct empty states so the message matches the actual reason:
    //   1. No services defined at all.
    //   2. All defined services are already in the order.
    //   3. Filter narrows the available list to zero.
    String? emptyMessage;
    if (widget.services.isEmpty) {
      emptyMessage = 'Belum ada layanan. Buat di tab Master Data.';
    } else if (widget.services.every((s) => widget.excludeIds.contains(s.id))) {
      emptyMessage = 'Semua layanan sudah dipilih.';
    } else if (filtered.isEmpty) {
      emptyMessage = 'Tidak ada layanan yang cocok dengan pencarian.';
    }

    // Flatten the grouped view into a list of widgets. Each entry is
    // either a category header (only when viewing "Semua") or a service
    // tile. We need a flat list (not ListView.separated) because headers
    // don't share a uniform separator slot with tiles — the gaps after
    // a header are bigger than the gaps between tiles.
    final items = <Widget>[];
    if (emptyMessage == null) {
      for (final catId in sortedCategoryIds) {
        // Skip the redundant category header when a single category is
        // filtered in — the pill above already tells the user what
        // they're looking at.
        if (_categoryFilterId == null) {
          items.add(_PickerCategoryHeader(category: catsById[catId]));
          items.add(const SizedBox(height: 8));
        }
        for (final s in groups[catId]!) {
          items.add(_PickerServiceTile(
            service: s,
            onTap: () => _onPick(s),
          ));
          items.add(const SizedBox(height: 8));
        }
      }
      // Drop the trailing separator so the last row hugs the bottom
      // padding cleanly.
      if (items.isNotEmpty) items.removeLast();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 520),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pinned header: title + close. Pinned (not in scroll view)
            // so the user always has an obvious escape hatch even while
            // scrolling a long result list.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Text('Pilih Layanan', style: AppTextStyles.titleLg),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),
            // Pinned search field. AppTextField.outlined (not search) here
            // because the dialog already provides its own surface.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppTextField(
                label: '',
                hint: 'Cari layanan...',
                prefixIcon: Icons.search,
                variant: AppTextFieldVariant.search,
                controller: _searchCtrl,
              ),
            ),
            const SizedBox(height: 8),
            // Pinned category pills. Horizontal scroll so the row never
            // wraps to multiple lines regardless of how many categories
            // the tenant has.
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryChip(
                      label: 'Semua',
                      selected: _categoryFilterId == null,
                      onTap: () => setState(() => _categoryFilterId = null),
                    ),
                    const SizedBox(width: 8),
                    for (final c in widget.categories) ...[
                      _CategoryChip(
                        label: c.name,
                        selected: _categoryFilterId == c.id,
                        onTap: () => setState(() => _categoryFilterId = c.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1),
            // Scrollable result list. Expanded so it claims the remaining
            // dialog height; ListView.separated for 8px gaps between rows
            // that match the main Layanan list spacing.
            Flexible(
              child: emptyMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          emptyMessage,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      children: items,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category section header inside the picker dialog. Same visual
/// language as the master-data list — tiny category icon + uppercase
/// tracking-wide label — so the operator's eye already knows how to
/// scan it. Only renders when the dialog is in "Semua" mode; when a
/// single category is filtered in, the pill above is the label and the
/// in-list header would be redundant.
class _PickerCategoryHeader extends StatelessWidget {
  const _PickerCategoryHeader({this.category});
  final ServiceCategory? category;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          _OrderCategoryIcon(
            iconUrl: category?.iconUrl,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            category?.name ?? 'Kategori',
            style: AppTextStyles.labelSm.copyWith(
              color: context.colors.outline,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row inside the picker dialog. Tappable as a whole; visual
/// feedback comes from the InkWell ripple + the trailing `+` icon (so
/// the affordance reads as "add" rather than "select").
class _PickerServiceTile extends StatelessWidget {
  const _PickerServiceTile({required this.service, required this.onTap});
  final Service service;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.input),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: context.colors.outlineVariant, width: 1),
          ),
          child: Row(
            children: [
              _OrderCategoryIcon(
                iconUrl: service.effectiveIconUrl,
                size: 36,
                rounded: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: AppTextStyles.bodyLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rupiah.format(service.price)} / ${service.unit}',
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.add_circle_outline,
                size: 22,
                color: context.colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact icon thumbnail untuk daftar Layanan. Render gambar dari
/// icon_url kalau ada; fallback ke Material icon kalau URL null/kosong/
/// gagal load. Background pakai secondaryContainer dengan icon tint
/// secondary — kebaca di atas surface putih Layanan row + picker tile.
class _OrderCategoryIcon extends StatelessWidget {
  const _OrderCategoryIcon({
    required this.iconUrl,
    this.size = 24,
    this.rounded = false,
  });

  final String? iconUrl;
  final double size;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final hasImage = iconUrl != null && iconUrl!.isNotEmpty;
    const bg = AppColors.secondaryContainer;
    const fallbackIcon = AppColors.secondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(rounded ? size / 4 : size / 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              iconUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.local_laundry_service_outlined,
                size: size * 0.55,
                color: fallbackIcon,
              ),
              loadingBuilder: (ctx, child, prog) => prog == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            )
          : Icon(
              Icons.local_laundry_service_outlined,
              size: size * 0.55,
              color: fallbackIcon,
            ),
    );
  }
}
