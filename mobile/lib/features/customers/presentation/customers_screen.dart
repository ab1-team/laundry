import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tab_header.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/customer.dart';
import 'customers_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customersProvider);
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          AppTabHeader(
            title: 'Pelanggan',
            onTrailingTap: () => context.push('/settings'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: AppTextField(
              label: '',
              hint: 'Cari nama atau nomor HP...',
              controller: _searchCtrl,
              prefixIcon: Icons.search,
              variant: AppTextFieldVariant.search,
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Error: $e', style: TextStyle(color: context.colors.error)),
                  ),
                  data: (all) {
                    final q = _search.toLowerCase();
                    final list = q.isEmpty
                        ? all
                        : all.where((c) =>
                            c.name.toLowerCase().contains(q) ||
                            (c.phone?.toLowerCase().contains(q) ?? false)).toList();
                    if (list.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async => ref.invalidate(customersProvider),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            _EmptyState(
                              text: q.isEmpty
                                  ? 'Belum ada pelanggan'
                                  : 'Pelanggan tidak ditemukan',
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(customersProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _CustomerRow(
                          key: ValueKey(list[i].id),
                          customer: list[i],
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: FloatingActionButton.extended(
                    heroTag: 'fab-customer',
                    onPressed: () => _openCustomerSheet(context, ref),
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryContainer,
                    icon: const Icon(Icons.add),
                    label: const Text('Pelanggan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerRow extends ConsumerStatefulWidget {
  const _CustomerRow({super.key, required this.customer});
  final Customer customer;

  @override
  ConsumerState<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends ConsumerState<_CustomerRow> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final initials = c.name.isEmpty ? '?' : c.name.substring(0, 1).toUpperCase();
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.summary),
      child: InkWell(
        onTap: _deleting ? null : () => _openCustomerSheet(context, ref, customer: c),
        borderRadius: BorderRadius.circular(AppRadius.summary),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.summary),
            border: Border.all(color: context.colors.surfaceContainerHigh, width: 1),
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
                    initials,
                    style: AppTextStyles.titleLg.copyWith(color: AppColors.secondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.phone ?? '—',
                      style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${c.totalOrders} order',
                style: AppTextStyles.labelSm.copyWith(color: context.colors.onSurfaceVariant),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: _deleting
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.delete_outline, color: context.colors.error),
                        onPressed: () => _confirmDelete(context, c),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Customer c) async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Hapus Pelanggan?'),
        content: Text('"${c.name}" akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(customerRepositoryProvider).delete(c.id);
      ref.invalidate(customersProvider);
    } catch (e) {
      if (mounted) setState(() => _deleting = false);
      if (context.mounted) _toast(context, 'Gagal: $e');
    }
  }
}

// ===========================================
// Add / Edit sheet
// ===========================================

void _openCustomerSheet(BuildContext context, WidgetRef ref, {Customer? customer}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomerSheet(customer: customer),
  );
}

class _CustomerSheet extends ConsumerStatefulWidget {
  const _CustomerSheet({this.customer});
  final Customer? customer;

  @override
  ConsumerState<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends ConsumerState<_CustomerSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name ?? '');
    _address = TextEditingController(text: widget.customer?.address ?? '');
    _notes = TextEditingController(text: widget.customer?.notes ?? '');
    // For new customers, seed the phone field with the Indonesian
    // country code "628" so the user just types the remaining digits.
    // Edit mode leaves the existing value untouched. Selection sits at
    // the end of "628" so the first keystroke continues the number.
    final seed = widget.customer?.phone ??
        (widget.customer == null ? '628' : '');
    _phone = TextEditingController(text: seed);
    _phone.selection = TextSelection.collapsed(offset: seed.length);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
      final address = _address.text.trim().isEmpty ? null : _address.text.trim();
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      await repo.create(
        name: _name.text.trim(),
        phone: phone,
        address: address,
        notes: notes,
      );
      ref.invalidate(customersProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) _toast(context, 'Gagal: $e');
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
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
                      'Tambah Pelanggan',
                      style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface),
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
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Alamat',
                        hint: 'Opsional',
                        controller: _address,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Catatan',
                        hint: 'Opsional',
                        controller: _notes,
                        maxLines: 4,
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
// Shared bits
// ===========================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: context.colors.outline),
            const SizedBox(height: 12),
            Text(
              text,
              style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String msg) {
  showAppSnackBar(context, msg);
}