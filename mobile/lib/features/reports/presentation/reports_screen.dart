import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_tab_header.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  // 'daily' = Harian, 'weekly' = Mingguan (no-op for now), 'monthly' = Bulanan.
  String _period = 'daily';
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final endpoint = switch (_period) {
        'monthly' => '/reports/income/monthly',
        'weekly'  => '/reports/income/weekly',
        _         => '/reports/income/daily',
      };
      final res = await ApiClient.instance.dio.get(endpoint);
      _data = (res.data as Map)['data'] as Map<String, dynamic>;
    } catch (_) {
      _data = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setPeriod(String p) {
    if (p == _period) return;
    setState(() => _period = p);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // DESIGN.md: "01 Okt - 31 Okt 2023" for monthly, "01 Okt - 07 Okt" for daily (7-day window).
    final rangeLabel = switch (_period) {
      'monthly' => '01 ${DateFormat('MMM', 'id_ID').format(DateTime(now.year, now.month, 1))} – ${DateFormat('d MMM yyyy', 'id_ID').format(now)}',
      'weekly'  => '${DateFormat('d MMM', 'id_ID').format(DateTime.now().subtract(const Duration(days: 7 * 11)))} – ${DateFormat('d MMM yyyy', 'id_ID').format(now)}',
      _         => '${DateFormat('d MMM', 'id_ID').format(now.subtract(const Duration(days: 6)))} – ${DateFormat('d MMM', 'id_ID').format(now)}',
    };

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          AppTabHeader(
            title: 'Laporan Bisnis',
            onTrailingTap: () => context.push('/settings'),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
            // ---- Header (title + Export) ----------------------------------
            // DESIGN.md: title 'Laporan Bisnis' (headline-md primary) on
            // the left, Export PDF/CSV pill on the right, both in one row.
            // ---- Date range pill + Export pill ---------------------------
            // DESIGN.md: date range on the left, Export PDF/CSV pill on
            // The date range that used to live next to the Export pill
            // was redundant — the period tabs (Harian / Mingguan /
            // Bulanan) already define the range, and the pill itself
            // wasn't tappable. The range still gets baked into the PDF
            // header, so it isn't lost as information; it just doesn't
            // earn a slot in the on-screen UI anymore.
            Align(
              alignment: Alignment.centerRight,
              child: _ExportPill(
                incomeData: _data,
                period: _period,
                rangeLabel: rangeLabel,
              ),
            ),

            const SizedBox(height: 20),

            // ---- Revenue card --------------------------------------------
            _RevenueCard(
              loading: _loading,
              data: _data,
              period: _period,
              onPeriodChanged: _setPeriod,
            ),

            const SizedBox(height: 24),

            // ---- Layanan Terpopuler (bar chart) --------------------------
            const _SectionTitle('Layanan Terpopuler'),
            const SizedBox(height: 12),
            const _PopularServicesCard(),
          ],
        ),
      ),
      ),
      ],
    ),
    );
  }
}

// ============================================================
// Export pill
// ============================================================

class _ExportPill extends StatefulWidget {
  const _ExportPill({
    required this.incomeData,
    required this.period,
    required this.rangeLabel,
  });

  /// The income payload already loaded by the parent (`/income/daily` or
  /// `/income/monthly`). Kept nullable so the pill can show a disabled
  /// state until the first fetch resolves.
  final Map<String, dynamic>? incomeData;

  /// Display label for the active period — embedded in the PDF header.
  final String period;
  final String rangeLabel;

  @override
  State<_ExportPill> createState() => _ExportPillState();
}

class _ExportPillState extends State<_ExportPill> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy || widget.incomeData == null) return;
    setState(() => _busy = true);
    try {
      // Services are loaded on demand here rather than lifted to the
      // parent state — the export path is the only consumer, so we
      // avoid a second request on every tab switch.
      List<dynamic> services = const [];
      try {
        final res = await ApiClient.instance.dio.get('/reports/services');
        services = ((res.data as Map)['data'] as Map)['data'] as List;
      } catch (_) {
        // Services are a "nice to have" section in the PDF; if the
        // request fails we still ship the income report.
      }

      final bytes = await _buildReportPdf(
        income: widget.incomeData!,
        period: widget.period,
        rangeLabel: widget.rangeLabel,
        services: services,
      );

      // In-app preview — `Printing.layoutPdf` opens the native print
      // sheet (iOS) / Android print framework (Android) which lets the
      // operator save or share without leaving the app.
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Gagal export: $e', type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _busy || widget.incomeData == null;
    return Material(
      color: AppColors.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: disabled ? null : _export,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onSecondaryContainer,
                  ),
                )
              else
                const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.onSecondaryContainer),
              const SizedBox(width: 6),
              Text(
                _busy ? 'Membuat...' : 'Export PDF',
                style: AppTextStyles.labelLg.copyWith(color: AppColors.onSecondaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Build a one-page PDF report from the current income + services
/// data. Layout matches the on-screen sections so the print preview
/// reads as a faithful export of what's on the device.
Future<Uint8List> _buildReportPdf({
  required Map<String, dynamic> income,
  required String period,
  required String rangeLabel,
  required List<dynamic> services,
}) async {
  final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFmt = DateFormat('d MMM yyyy', 'id_ID');
  final summary = (income['summary'] as Map?) ?? const {};
  final totalIncome = (summary['total_income'] as num?)?.toDouble() ?? 0;
  final totalTx = (summary['total_tx'] as num?)?.toInt() ?? 0;
  final averageDaily = (summary['average_daily'] as num?)?.toDouble();
  final periodLabel = switch (period) {
    'monthly' => 'Bulanan',
    'weekly'  => 'Mingguan',
    _         => 'Harian',
  };

  // Load a Unicode-capable TTF (Lato) bundled under assets/fonts/.
  // The `pdf` package's default Helvetica only supports Latin-1, so
  // characters like the en-dash (–) used in our date range labels
  // raise "Helvetica has no Unicode support" at draw time. Registering
  // the bundled font at document construction keeps the rest of the
  // builder code using plain `pw.TextStyle(...)` — `Theme.withFont`
  // makes it the default for every paragraph.
  final regular = await rootBundle.load('assets/fonts/Lato-Regular.ttf');
  final bold    = await rootBundle.load('assets/fonts/Lato-Bold.ttf');
  final ttfRegular = pw.Font.ttf(regular);
  final ttfBold    = pw.Font.ttf(bold);

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        // ---- Header ----
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Laporan Bisnis',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Periode: $periodLabel',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                pw.Text(rangeLabel,
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('LaundryKu',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Dicetak: ${dateFmt.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // ---- Pendapatan summary ----
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1A2340), // AppColors.primary
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Total Pendapatan',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey300)),
              pw.SizedBox(height: 6),
              pw.Text(rupiah.format(totalIncome),
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  )),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Text('$totalTx transaksi',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
                  if (averageDaily != null) ...[
                    pw.SizedBox(width: 12),
                    pw.Text('Rata-rata: ${rupiah.format(averageDaily)} / hari',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
                  ],
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // ---- Pendapatan harian / bulanan breakdown ----
        if ((income['data'] as List?)?.isNotEmpty == true) ...[
          pw.Text('Rincian Pendapatan',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfIncomeTable(income['data'] as List, period: period, rupiah: rupiah),
          pw.SizedBox(height: 20),
        ],

        // ---- Layanan Terpopuler ----
        if (services.isNotEmpty) ...[
          pw.Text('Layanan Terpopuler',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfServicesTable(services, rupiah: rupiah),
        ],
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfIncomeTable(List<dynamic> rows, {required String period, required NumberFormat rupiah}) {
  return pw.TableHelper.fromTextArray(
    headers: [
      switch (period) {
        'monthly' => 'Bulan',
        'weekly'  => 'Mulai',
        _         => 'Tanggal',
      },
      'Pendapatan',
      'Transaksi',
    ],
    data: rows.map<List<String>>((r) {
      final label = switch (period) {
        'monthly' => (r['month_label'] as String? ?? r['month'] as String? ?? '-'),
        'weekly'  => (r['week_label'] as String? ?? r['week_start'] as String? ?? '-'),
        // Daily falls back through date_label ("24 Jun") → ISO date
        // ("2026-06-24") → "-" so the column is never literally empty.
        _         => (r['date_label'] as String? ?? r['date'] as String? ?? '-'),
      };
      return [
        label,
        rupiah.format((r['total'] as num?)?.toDouble() ?? 0),
        '${(r['transactions'] as num?)?.toInt() ?? 0}',
      ];
    }).toList(),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellStyle: const pw.TextStyle(fontSize: 10),
    headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(2),
      2: const pw.FlexColumnWidth(1),
    },
  );
}

pw.Widget _pdfServicesTable(List<dynamic> services, {required NumberFormat rupiah}) {
  return pw.TableHelper.fromTextArray(
    headers: const ['Layanan', 'Qty', 'Order', 'Pendapatan'],
    data: services.take(10).map<List<String>>((s) {
      return [
        (s['service_name'] as String?) ?? '-',
        ((s['total_qty'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
        '${(s['order_count'] as num?)?.toInt() ?? 0}',
        rupiah.format((s['total_revenue'] as num?)?.toDouble() ?? 0),
      ];
    }).toList(),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellStyle: const pw.TextStyle(fontSize: 10),
    headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(1),
      3: const pw.FlexColumnWidth(2),
    },
  );
}

// ============================================================
// Revenue card
// ============================================================

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.loading,
    required this.data,
    required this.period,
    required this.onPeriodChanged,
  });

  final bool loading;
  final Map<String, dynamic>? data;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final total = (data?['summary'] as Map?)?['total_income'];
    // DESIGN.md shows a fixed "+12% dari bulan lalu" + "Updated: 10:24 AM"
    // — they're demo copy, but the data shape we have today doesn't carry
    // a "vs previous period" delta. We render the trend line from data
    // when present, else hide the row to avoid a misleading hard-coded %.
    final delta = (data?['summary'] as Map?)?['delta_pct'];
    final updatedAt = (data?['summary'] as Map?)?['updated_at'] as String?;
    final updatedLabel = updatedAt == null
        ? null
        : 'Updated: ${DateFormat('HH:mm').format(DateTime.parse(updatedAt).toLocal())}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // Reads from active scheme — Navy in light, Sky Blue in dark —
        // so the hero stat card stays visually distinct from the dark
        // background. AppColors.primary (Navy) would collapse onto the
        // dark surface in dark mode.
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Primary-tinted soft shadow, consistent with Order/Customer
        // cards. The design HTML uses a black drop-shadow, but staying
        // on-primary matches the rest of the app.
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Pendapatan',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onPrimaryContainer),
          ),
          const SizedBox(height: 8),
          if (loading)
            const SizedBox(
              height: 32,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                ),
              ),
            )
          else
            Text(
              rupiah.format(total ?? 0),
              // headlineMd (22) so the revenue number reads as the page
              // anchor without out-scaling the rest of the app — Order
              // detail's "Total Harga" and section titles use the same
              // size, keeping typography consistent across surfaces.
              style: AppTextStyles.headlineMd.copyWith(color: AppColors.onPrimary),
            ),
          const SizedBox(height: 20),

          // Period segmented control — DESIGN.md: primaryContainer
          // track with secondary-filled selected tab.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _PeriodTab(label: 'Harian',   selected: period == 'daily',   onTap: () => onPeriodChanged('daily')),
                _PeriodTab(label: 'Mingguan', selected: period == 'weekly',  onTap: () => onPeriodChanged('weekly')),
                _PeriodTab(label: 'Bulanan',  selected: period == 'monthly', onTap: () => onPeriodChanged('monthly')),
              ],
            ),
          ),

          if (delta != null || updatedLabel != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (delta != null) ...[
                  const Icon(Icons.trending_up, size: 14, color: AppColors.secondaryContainer),
                  const SizedBox(width: 6),
                  Text(
                    '+$delta% dari periode lalu',
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.secondaryContainer),
                  ),
                ],
                if (delta != null && updatedLabel != null) const Spacer(),
                if (updatedLabel != null)
                  Text(
                    updatedLabel,
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.onPrimaryContainer.withValues(alpha: 0.60)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.labelLg.copyWith(
              color: selected ? AppColors.onSecondary : AppColors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Layanan Terpopuler (fl_chart BarChart)
// ============================================================

class _PopularServicesCard extends StatefulWidget {
  const _PopularServicesCard();

  @override
  State<_PopularServicesCard> createState() => _PopularServicesCardState();
}

class _PopularServicesCardState extends State<_PopularServicesCard> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final res = await ApiClient.instance.dio.get('/reports/services');
    return ((res.data as Map)['data'] as Map)['data'] as List;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
          }
          final services = snap.data!.take(5).toList();
          if (services.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Belum ada data',
                  style: AppTextStyles.bodyMd,
                ),
              ),
            );
          }
          return _ServicesBarChart(services: services);
        },
      ),
    );
  }
}

class _ServicesBarChart extends StatelessWidget {
  const _ServicesBarChart({required this.services});
  final List<dynamic> services;

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final maxRev = services
        .map((s) => (s['total_revenue'] as num).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    // Round the chart ceiling up so the tallest bar doesn't kiss the
    // top edge — gives the labels breathing room.
    final chartMaxY = (maxRev * 1.20).clamp(1, double.infinity).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: chartMaxY,
              minY: 0,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) {
                    final s = services[group.x.toInt()];
                    return BarTooltipItem(
                      '${s['service_name']}\n${rupiah.format(rod.toY)}',
                      AppTextStyles.labelSm.copyWith(color: AppColors.onPrimary),
                    );
                  },
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, _) {
                      final i = value.toInt();
                      if (i < 0 || i >= services.length) return const SizedBox.shrink();
                      final name = services[i]['service_name'] as String;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          name,
                          style: AppTextStyles.labelSm.copyWith(color: context.colors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < services.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (services[i]['total_revenue'] as num).toDouble(),
                        color: AppColors.secondary,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend row — single accent dot for the bar series. DESIGN.md
        // had Ekspres/Reguler pairs; we collapse to one since the data
        // doesn't carry that distinction yet.
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              'Pendapatan layanan',
              style: AppTextStyles.labelSm.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Section title (shared by Layanan Terpopuler)
// ============================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text, style: AppTextStyles.titleLg),
    );
  }
}

