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
    required this.name,
    required this.unit,
    required this.categoryIconUrl,
    required this.price,
  }) : qty = 1;
  final int serviceId;
  final int categoryId;
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
  // Filter pill on the Layanan section. `null` = "Semua" (show every category).
  // No longer drives selection — service selection is now multi-checkbox.
  int? _categoryFilterId;
  // Selected line items; each entry is a service the operator checked off,
  // with its own qty. Order = display order under Layanan.
  final List<_LineItem> _items = [];
  // O(1) "is this service currently in _items?" lookup, mirrors _items keys.
  final Set<int> _checkedServiceIds = <int>{};
  String _payment = 'lunas'; // lunas | dp | hutang
  String _method = 'cash';
  final _notesCtrl = TextEditingController();
  // DP amount (uang muka). Only used when _payment == 'dp'. Edited via
  // the inline input that appears under the segmented control.
  final _dpCtrl = TextEditingController();
  // In-memory search filter for the Layanan list. Filters by service
  // name (case-insensitive contains). Combines with _categoryFilterId
  // (both must match). No debounce — the dataset is small and the
  // filter runs synchronously against the cached servicesProvider.
  final _serviceSearchCtrl = TextEditingController();
  String _serviceSearch = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Rebuild the "sisa" hint under the DP field as the operator types.
    _dpCtrl.addListener(() => setState(() {}));
    // Rebuild the Layanan list as the operator types in the search box.
    _serviceSearchCtrl.addListener(() {
      if (_serviceSearch != _serviceSearchCtrl.text) {
        setState(() => _serviceSearch = _serviceSearchCtrl.text);
      }
    });
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

  /// Toggle a service in/out of the order. Adds with default qty=1, removes
  /// the existing line entirely (qty + row) when toggled off — no separate
  /// delete button needed because unchecking achieves the same effect.
  void _toggleService(Service service) {
    setState(() {
      if (_checkedServiceIds.contains(service.id)) {
        _items.removeWhere((i) => i.serviceId == service.id);
        _checkedServiceIds.remove(service.id);
      } else {
        _items.add(_LineItem(
          serviceId: service.id,
          categoryId: service.categoryId,
          name: service.name,
          unit: service.unit,
          categoryIconUrl: service.effectiveIconUrl,
          price: service.price,
        ));
        _checkedServiceIds.add(service.id);
      }
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
    _serviceSearchCtrl.dispose();
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
          // Search box for filtering services by name. In-memory only
          // — combines with the category chip filter below (both must
          // match). Empty input shows the full list (subject to the
          // category filter alone).
          AppTextField(
            label: '',
            hint: 'Cari layanan...',
            prefixIcon: Icons.search,
            variant: AppTextFieldVariant.search,
            controller: _serviceSearchCtrl,
          ),
          const SizedBox(height: 12),
          // Category filter row. "Semua" pill = null filter (show every
          // category's services, grouped). Tapping a category pill filters
          // the visible services to that one category only. Multi-select on
          // services lives inside the list below.
          categoriesAsync.when(
            loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Gagal: $e', style: TextStyle(color: context.colors.error)),
            data: (cats) {
              if (cats.isEmpty) {
                return Text('Belum ada kategori. Buat di tab Master Data.',
                    style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant));
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CategoryChip(
                      label: 'Semua',
                      selected: _categoryFilterId == null,
                      onTap: () => setState(() => _categoryFilterId = null),
                    ),
                    const SizedBox(width: 8),
                    for (final c in cats) ...[
                      _CategoryChip(
                        label: c.name,
                        selected: _categoryFilterId == c.id,
                        onTap: () => setState(() => _categoryFilterId = c.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Service list, grouped by category. Each row is a checkbox card;
          // checking a row expands an inline qty stepper below the name.
          servicesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Gagal: $e', style: TextStyle(color: context.colors.error)),
            data: (all) {
              if (all.isEmpty) {
                return Text('Belum ada layanan.',
                    style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant));
              }
              // Group by categoryId; preserve category order via Map iteration
              // (insertion order) so the list mirrors the filter pills above.
              // Apply category filter first, then name search (both must match).
              final q = _serviceSearch.trim().toLowerCase();
              final filtered = all.where((s) {
                if (_categoryFilterId != null && s.categoryId != _categoryFilterId) return false;
                if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
                return true;
              }).toList();
              // Empty-state for "no rows match the current filter combo".
              // Distinguishes "no services defined" (handled above) from
              // "services exist but filter narrows to none" — so the user
              // knows to clear the search/category instead of creating a
              // new service.
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Tidak ada layanan yang cocok dengan pencarian.',
                    style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                );
              }
              final groups = <int, List<Service>>{};
              for (final s in filtered) {
                groups.putIfAbsent(s.categoryId, () => <Service>[]).add(s);
              }
              // When viewing "Semua", sort the category groups by the
              // category's display order (sort_order) so the order
              // matches the filter pills above and what the owner set
              // in Master Data. With a single-category filter the
              // groups Map only has one entry so sort is a no-op.
              List<MapEntry<int, List<Service>>> sortedEntries = groups.entries.toList();
              if (_categoryFilterId == null) {
                final catsById = {
                  for (final c in categoriesAsync.value ?? const <ServiceCategory>[]) c.id: c,
                };
                sortedEntries.sort((a, b) {
                  final ao = catsById[a.key]?.sortOrder ?? 0;
                  final bo = catsById[b.key]?.sortOrder ?? 0;
                  if (ao != bo) return ao.compareTo(bo);
                  // Tie-break by name so equal sort_order values get a
                  // deterministic (alphabetical) ordering.
                  final an = catsById[a.key]?.name ?? '';
                  final bn = catsById[b.key]?.name ?? '';
                  return an.compareTo(bn);
                });
              }
              return ConstrainedBox(
                // Cap the visible service list so a tenant with many
                // services doesn't push the payment/total sections off
                // the screen. The list scrolls internally; the outer
                // page ListView continues to drive the rest of the form.
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in sortedEntries) ...[
                        // Category section title only renders when
                        // viewing "Semua" (multiple categories shown
                        // at once). When a single category is filtered
                        // in, the title is redundant — the filter pill
                        // already tells the user what they're looking
                        // at — so we hide it for a cleaner list.
                        if (_categoryFilterId == null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                            child: Row(
                              children: [
                                _OrderCategoryIcon(
                                  // Prefer service.icon (override) kalau
                                  // ada; kalau tidak, ambil icon kategori
                                  // lewat catsById lookup di bawah.
                                  iconUrl: entry.value.first.effectiveIconUrl,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  // Local label fallback — the service model exposes
                                  // categoryName only when joined server-side; for the
                                  // standalone master load we fall back to the
                                  // category filter chip the user is currently inside.
                                  // In practice backend joins always populate this.
                                  entry.value.first.categoryName ?? _categoryFilterLabel(categoriesAsync, entry.key),
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: context.colors.outline,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        for (final s in entry.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildServiceRow(s),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
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

  String _categoryFilterLabel(AsyncValue<List<ServiceCategory>> categoriesAsync, int id) {
    return categoriesAsync.maybeWhen(
      data: (cats) => cats.firstWhere((c) => c.id == id, orElse: () => cats.first).name,
      orElse: () => 'Kategori',
    );
  }

  Widget _buildServiceRow(Service s) {
    final checked = _checkedServiceIds.contains(s.id);
    final idx = _items.indexWhere((i) => i.serviceId == s.id);
    final line = idx >= 0 ? _items[idx] : null;
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        // Checked rows use the primary fill so the user reads the
        // selection at a glance; unchecked rows sit on white.
        color: checked ? context.colors.primary : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: checked ? context.colors.primary : context.colors.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: () => _toggleService(s),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Thumbnail icon — kalau service ada icon, tampil
                    // sebagai image 28x28 rounded. Fallback ke icon
                    // kategori via effectiveIconUrl atau placeholder
                    // laundry icon.
                    _OrderCategoryIcon(
                      iconUrl: s.effectiveIconUrl,
                      size: 28,
                      rounded: true,
                      onPrimary: checked,
                    ),
                    const SizedBox(width: 10),
                    // No leading checkbox icon — selection is conveyed by
                    // the row's primary fill + bold text. Tapping anywhere
                    // on the row toggles the selection.
                    Expanded(
                      child: Text(
                        s.name,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: checked ? AppColors.onPrimary : context.colors.onSurface,
                          fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      '${rupiah.format(s.price)} / ${s.unit}',
                      style: AppTextStyles.labelLg.copyWith(
                        color: checked ? AppColors.onPrimary : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                // Expanded section only renders for checked rows. Animates
                // in via AnimatedSize so toggling feels smooth.
                AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  child: line == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              _MiniStepperBtn(
                                icon: Icons.remove,
                                onTap: () => _decrementQty(idx),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  line.qty.toStringAsFixed(1),
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.titleLg.copyWith(color: AppColors.onPrimary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _MiniStepperBtn(
                                icon: Icons.add,
                                onTap: () => _incrementQty(idx),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                line.unit,
                                style: AppTextStyles.labelLg.copyWith(color: AppColors.onPrimary),
                              ),
                              const Spacer(),
                              Text(
                                rupiah.format(line.subtotal),
                                style: AppTextStyles.bodyLg.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
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

// Compact 32x32 stepper button used inside each checked service row.
// White-on-primary tint ensures it reads against the primary-fill
// selected row background.
class _MiniStepperBtn extends StatelessWidget {
  const _MiniStepperBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onPrimary.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.onPrimary, size: 18),
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

/// Compact icon thumbnail untuk daftar Layanan. Render gambar dari
/// icon_url kalau ada; fallback ke Material icon kalau URL null/kosong/
/// gagal load. Saat [onPrimary] true (service row yang dipilih),
/// background & fallback tint di-adjust supaya tetap kebaca di atas
/// primary fill.
class _OrderCategoryIcon extends StatelessWidget {
  const _OrderCategoryIcon({
    required this.iconUrl,
    this.size = 24,
    this.rounded = false,
    this.onPrimary = false,
  });

  final String? iconUrl;
  final double size;
  final bool rounded;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final hasImage = iconUrl != null && iconUrl!.isNotEmpty;
    final bg = onPrimary
        ? AppColors.onPrimary.withValues(alpha: 0.18)
        : AppColors.secondaryContainer;
    final fallbackIcon = onPrimary
        ? AppColors.onPrimary
        : AppColors.secondary;
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
