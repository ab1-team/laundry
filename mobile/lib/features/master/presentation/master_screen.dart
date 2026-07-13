import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tab_header.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/service.dart';
import '../data/service_category.dart';
import 'master_provider.dart';

class MasterScreen extends ConsumerStatefulWidget {
  const MasterScreen({super.key});

  @override
  ConsumerState<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends ConsumerState<MasterScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          AppTabHeader(
            title: 'Master Data',
            onTrailingTap: () => context.push('/settings'),
          ),
          // Tab strip
          Container(
            color: context.colors.surface,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: context.colors.onSurfaceVariant,
              indicatorColor: AppColors.secondary,
              indicatorWeight: 3,
              labelStyle: AppTextStyles.labelLg,
              unselectedLabelStyle: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Kategori'),
                Tab(text: 'Layanan'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                _CategoryTab(),
                _ServiceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================
// Tab 1: Service Categories
// ===========================================

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);
    return Stack(
      children: [
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: context.colors.error))),
          data: (cats) {
            if (cats.isEmpty) return const _EmptyState(text: 'Belum ada kategori');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(categoriesProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: cats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _CategoryRow(key: ValueKey(cats[i].id), category: cats[i]),
              ),
            );
          },
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'fab-cat',
            onPressed: () => _openCategorySheet(context, ref, null),
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: AppColors.onSecondaryContainer,
            icon: const Icon(Icons.add),
            label: const Text('Kategori'),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends ConsumerStatefulWidget {
  const _CategoryRow({super.key, required this.category});
  final ServiceCategory category;

  @override
  ConsumerState<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends ConsumerState<_CategoryRow> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.summary),
      child: InkWell(
        onTap: _deleting ? null : () => _openCategorySheet(context, ref, category),
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
              _LeadingIcon(url: category.iconUrl, fallback: Icons.category_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name, style: AppTextStyles.titleLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${category.servicesCount} layanan',
                      style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // While deleting, replace the trash button with a small
              // spinner so the user sees the row is in-flight. Disable
              // taps so a second delete can't be queued.
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
                        onPressed: () => _confirmDelete(context, category),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ServiceCategory cat) async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(name: cat.name),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(masterRepositoryProvider).deleteCategory(cat.id);
      ref.invalidate(categoriesProvider);
    } catch (e) {
      if (mounted) setState(() => _deleting = false);
      if (context.mounted) _toast(context, 'Gagal: $e');
    }
  }
}

void _openCategorySheet(BuildContext context, WidgetRef ref, ServiceCategory? cat) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategorySheet(category: cat),
  );
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.category});
  final ServiceCategory? category;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final TextEditingController _name;
  late final TextEditingController _sort;
  // FK ke tabel icons (nullable). Null = kategori tanpa icon.
  int? _selectedIconId;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _sort = TextEditingController(text: '${widget.category?.sortOrder ?? 0}');
    _selectedIconId = widget.category?.iconId;
    _active = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(masterRepositoryProvider);
      if (widget.category == null) {
        await repo.createCategory(
          name: _name.text.trim(),
          iconId: _selectedIconId,
          sortOrder: int.tryParse(_sort.text) ?? 0,
          isActive: _active,
        );
      } else {
        await repo.updateCategory(
          widget.category!.id,
          name: _name.text.trim(),
          iconId: _selectedIconId,
          sortOrder: int.tryParse(_sort.text) ?? widget.category!.sortOrder,
          isActive: _active,
        );
      }
      ref.invalidate(categoriesProvider);
      ref.invalidate(servicesProvider);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        child: SafeArea(
          top: false,
          // Pinned header (handle + title) stays visible when the form
          // scrolls under the keyboard; only the form area scrolls.
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
                      widget.category == null ? 'Tambah Kategori' : 'Edit Kategori',
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
                        hint: 'Contoh: Cuci Kiloan',
                        controller: _name,
                      ),
                      const SizedBox(height: 12),
                      // Icon picker — grid 3 kolom dari icon yang sudah
                      // di-upload admin. Tahan null = tanpa icon.
                      Text('Icon', style: AppTextStyles.labelLg),
                      const SizedBox(height: 8),
                      _IconPickerGrid(
                        selectedIconId: _selectedIconId,
                        onChanged: (id) => setState(() => _selectedIconId = id),
                      ),
                      if (_selectedIconId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedIconId = null),
                              child: Text(
                                'Hapus icon',
                                style: AppTextStyles.bodyMd.copyWith(color: context.colors.error),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Urutan tampil',
                        hint: '0',
                        controller: _sort,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Aktif', style: AppTextStyles.labelLg),
                        subtitle: Text('Kategori non-aktif tidak muncul di Buat Order', style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant)),
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                      const SizedBox(height: 12),
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
// Tab 2: Services
// ===========================================

class _ServiceTab extends ConsumerStatefulWidget {
  const _ServiceTab();

  @override
  ConsumerState<_ServiceTab> createState() => _ServiceTabState();
}

class _ServiceTabState extends ConsumerState<_ServiceTab> {
  String _search = '';
  int? _filterCat;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final servicesAsync = ref.watch(servicesProvider);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: AppTextField(
                label: '',
                hint: 'Cari layanan...',
                controller: _searchCtrl,
                prefixIcon: Icons.search,
                variant: AppTextFieldVariant.search,
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            SizedBox(
              // 16 + 40 (labelLg pill) + 16 = 72 — enough that the 40px-tall
              // pill never gets clipped by the container.
              height: 72,
              child: categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (cats) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    _FilterPill(
                      label: 'Semua',
                      selected: _filterCat == null,
                      onTap: () => setState(() => _filterCat = null),
                    ),
                    const SizedBox(width: 8),
                    ...cats.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterPill(
                            label: c.name,
                            selected: _filterCat == c.id,
                            onTap: () => setState(() => _filterCat = c.id),
                          ),
                        )),
                  ],
                ),
              ),
            ),
            Expanded(
              child: servicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: context.colors.error))),
                data: (svcs) {
                  var list = svcs;
                  if (_filterCat != null) list = list.where((s) => s.categoryId == _filterCat).toList();
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    list = list.where((s) => s.name.toLowerCase().contains(q)).toList();
                  }
                  if (list.isEmpty) return const _EmptyState(text: 'Belum ada layanan');
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(servicesProvider);
                      ref.invalidate(categoriesProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _ServiceRow(key: ValueKey(list[i].id), service: list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'fab-svc',
            onPressed: () => _openServiceSheet(context, ref, null),
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: AppColors.onSecondaryContainer,
            icon: const Icon(Icons.add),
            label: const Text('Layanan'),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: AppTextStyles.labelLg.copyWith(
              color: selected ? AppColors.onPrimary : context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends ConsumerStatefulWidget {
  const _ServiceRow({super.key, required this.service});
  final Service service;

  @override
  ConsumerState<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends ConsumerState<_ServiceRow> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.summary),
      child: InkWell(
        onTap: _deleting ? null : () => _openServiceSheet(context, ref, service),
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
              _LeadingIcon(url: service.effectiveIconUrl, fallback: Icons.local_laundry_service_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (service.categoryName != null)
                      Text(
                        service.categoryName!.toUpperCase(),
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.secondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(service.name, style: AppTextStyles.titleLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      '${rupiah.format(service.price)} / ${service.unit}',
                      style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
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
                        onPressed: () => _confirmDelete(context, service),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Service svc) async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(
        name: svc.name,
        title: 'Hapus Layanan?',
        message: '"${svc.name}" akan dihapus.',
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(masterRepositoryProvider).deleteService(svc.id);
      ref.invalidate(servicesProvider);
    } catch (e) {
      if (mounted) setState(() => _deleting = false);
      if (context.mounted) _toast(context, 'Gagal: $e');
    }
  }
}

void _openServiceSheet(BuildContext context, WidgetRef ref, Service? svc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ServiceSheet(service: svc),
  );
}

class _ServiceSheet extends ConsumerStatefulWidget {
  const _ServiceSheet({this.service});
  final Service? service;

  @override
  ConsumerState<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends ConsumerState<_ServiceSheet> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _unit;
  late final TextEditingController _duration;
  late int? _categoryId;
  late int? _iconId;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.service?.name ?? '');
    _price = TextEditingController(text: widget.service?.price.toStringAsFixed(0) ?? '');
    _unit = TextEditingController(text: widget.service?.unit ?? 'kg');
    _duration = TextEditingController(text: '${widget.service?.durationHours ?? 24}');
    _categoryId = widget.service?.categoryId;
    _iconId = widget.service?.iconId;
    _active = widget.service?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _unit.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _categoryId == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(masterRepositoryProvider);
      final price = double.tryParse(_price.text.replaceAll('.', '')) ?? 0;
      final duration = int.tryParse(_duration.text) ?? 24;
      if (widget.service == null) {
        await repo.createService(
          categoryId: _categoryId!,
          iconId: _iconId,
          name: _name.text.trim(),
          price: price,
          unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
          durationHours: duration,
          isActive: _active,
        );
      } else {
        await repo.updateService(
          widget.service!.id,
          categoryId: _categoryId,
          iconId: _iconId,
          name: _name.text.trim(),
          price: price,
          unit: _unit.text.trim(),
          durationHours: duration,
          isActive: _active,
        );
      }
      ref.invalidate(servicesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) _toast(context, 'Gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        child: SafeArea(
          top: false,
          // Pinned header (handle + title) stays visible when the form
          // scrolls under the keyboard; only the form area scrolls.
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
                      widget.service == null ? 'Tambah Layanan' : 'Edit Layanan',
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
                      // Category picker (chip-style).
                      Text('Kategori', style: AppTextStyles.labelLg),
                      const SizedBox(height: 8),
                      categoriesAsync.when(
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                        error: (e, _) => Text('Gagal memuat kategori: $e', style: TextStyle(color: context.colors.error)),
                        data: (cats) {
                          if (cats.isEmpty) {
                            return Text(
                              'Buat kategori dulu di tab Kategori.',
                              style: AppTextStyles.bodyMd.copyWith(color: context.colors.error),
                            );
                          }
                          _categoryId ??= cats.first.id;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: cats.map((c) {
                              final selected = c.id == _categoryId;
                              return GestureDetector(
                                onTap: () => setState(() => _categoryId = c.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.secondary : context.colors.surface,
                                    border: Border.all(
                                      color: selected ? AppColors.secondary : context.colors.outlineVariant,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    c.name,
                                    style: AppTextStyles.labelLg.copyWith(
                                      color: selected ? AppColors.onSecondary : context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Nama layanan',
                        hint: 'Contoh: Cuci Kiloan Reguler',
                        controller: _name,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              label: 'Harga',
                              hint: '0',
                              controller: _price,
                              variant: AppTextFieldVariant.currency,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: 'Satuan',
                              hint: 'kg',
                              controller: _unit,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Durasi (jam)',
                        hint: '24',
                        controller: _duration,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Text('Icon (opsional)', style: AppTextStyles.labelLg),
                      const SizedBox(height: 8),
                      _IconPickerGrid(
                        selectedIconId: _iconId,
                        onChanged: (id) => setState(() => _iconId = id),
                      ),
                      if (_iconId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => setState(() => _iconId = null),
                              child: Text(
                                'Hapus icon',
                                style: AppTextStyles.bodyMd.copyWith(color: context.colors.error),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Aktif', style: AppTextStyles.labelLg),
                        subtitle: Text('Layanan non-aktif tidak muncul di Buat Order', style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant)),
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                      const SizedBox(height: 12),
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

// =====================
// Shared bits
// =====================

/// Shared delete confirmation. Tracks its own busy state so the
/// "Hapus" button shows a spinner while the caller is awaiting the
/// future returned by `Navigator.pop`. Caller is expected to push
/// `true` and then perform the actual delete.
class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({
    required this.name,
    this.title = 'Hapus Kategori?',
    this.message,
  });

  final String name;
  final String title;
  final String? message;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(widget.title),
      content: Text(widget.message ?? '"${widget.name}" akan dihapus.'),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _busy ? null : () {
            setState(() => _busy = true);
            Navigator.pop(context, true);
          },
          style: TextButton.styleFrom(foregroundColor: context.colors.error),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hapus'),
        ),
      ],
    );
  }
}

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
            Icon(Icons.inbox_outlined, size: 48, color: context.colors.outline),
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

// ===========================================
// Reusable Icon Widgets
// ===========================================

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.url, required this.fallback});
  final String? url;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: hasImage ? AppColors.secondaryContainer : AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(fallback, color: AppColors.secondary, size: 22),
              loadingBuilder: (ctx, child, prog) => prog == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            )
          : Icon(fallback, color: AppColors.secondary, size: 22),
    );
  }
}

/// Image.network dengan fallback icon. size untuk fallback icon.
class _NetworkIcon extends StatelessWidget {
  const _NetworkIcon({required this.url, required this.fallback, this.size = 22});
  final String? url;
  final IconData fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Center(child: Icon(fallback, color: AppColors.onSurfaceVariant, size: size));
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Center(child: Icon(fallback, color: AppColors.onSurfaceVariant, size: size)),
      loadingBuilder: (ctx, child, prog) => prog == null
          ? child
          : const Center(
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
    );
  }
}

/// Grid 3 kolom icon picker. Pilih dari iconsProvider (icon yang sudah
/// di-upload admin). Tahan null = tanpa icon. Tampilkan "Tanpa icon"
/// sebagai tile pertama agar user bisa unset.
class _IconPickerGrid extends ConsumerWidget {
  const _IconPickerGrid({required this.selectedIconId, required this.onChanged});
  final int? selectedIconId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(iconsProvider);
    return async.when(
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Gagal memuat icon: $e', style: AppTextStyles.bodySm.copyWith(color: context.colors.error)),
      ),
      data: (icons) {
        if (icons.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Belum ada icon. Buka tab Icon untuk upload.',
              style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: icons.length,
          itemBuilder: (_, i) {
            final ic = icons[i];
            final selected = ic.id == selectedIconId;
            return GestureDetector(
              onTap: () => onChanged(ic.id),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.secondaryContainer
                      : context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: selected ? AppColors.secondary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: _NetworkIcon(url: ic.iconUrl, fallback: Icons.image_outlined, size: 24),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ic.name,
                      style: AppTextStyles.labelSm.copyWith(
                        color: selected ? AppColors.onSecondaryContainer : context.colors.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
