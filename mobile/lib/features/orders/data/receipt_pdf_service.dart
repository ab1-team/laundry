import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/order_model.dart';

/// Generates the customer-facing receipt (nota) PDF for an order.
///
/// Output is sized for an 80mm thermal printer (~226pt wide). Same
/// layout also works for A4/Letter share/print — the content is short
/// enough to fit on one page in either case.
///
/// Header: tenant name (from [tenant]) + ticket + tanggal.
class ReceiptPdfService {
  // 80mm thermal width in PDF points (1mm = 2.835pt).
  static const double _thermalWidthPt = 80 * 2.835;

  // Indonesian rupiah formatter — match the rest of the app (no decimals).
  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _dateTime = DateFormat('d MMM y, HH:mm', 'id_ID');

  /// Build the PDF bytes for [order]. [tenant] is the Map returned by
  /// `GET /v1/settings/tenant` — may be empty if the tenant hasn't
  /// filled out their info yet (header falls back to a generic label).
  Future<Uint8List> build({
    required OrderModel order,
    required Map<String, dynamic> tenant,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _thermalWidthPt,
          double.infinity, // one continuous column, height grows with content
          marginAll: 8,
        ),
        build: (ctx) => _content(order, tenant),
      ),
    );
    return doc.save();
  }


  pw.Widget _content(OrderModel order, Map<String, dynamic> tenant) {
    final tenantName = (tenant['name'] as String?)?.trim();
    final tenantAddress = (tenant['address'] as String?)?.trim();
    final tenantPhone = (tenant['phone'] as String?)?.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header toko
        pw.Center(
          child: pw.Text(
            tenantName?.isNotEmpty == true ? tenantName! : 'LAUNDRY',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (tenantAddress?.isNotEmpty == true)
          pw.Center(
            child: pw.Text(
              tenantAddress!,
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (tenantPhone?.isNotEmpty == true)
          pw.Center(
            child: pw.Text(
              'Telp: $tenantPhone',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        pw.SizedBox(height: 6),
        _divider(),
        pw.SizedBox(height: 4),

        // Meta order
        _row('No. Tiket', order.ticketNumber, bold: true),
        _row('Tanggal', _dateTime.format(order.createdAt)),
        if (order.customerName?.isNotEmpty == true)
          _row('Pelanggan', order.customerName!),
        if (order.customerPhone?.isNotEmpty == true)
          _row('HP', order.customerPhone!),
        pw.SizedBox(height: 4),
        _divider(),
        pw.SizedBox(height: 4),

        // Items
        ...order.items.map(
          (it) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(it.serviceName, style: const pw.TextStyle(fontSize: 9)),
                pw.Row(
                  children: [
                    pw.Text(
                      '${_fmtQty(it.qty)} ${it.unit} × ${_rupiah.format(it.price)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      _rupiah.format(it.subtotal),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        _divider(),

        // Totals
        _row('Subtotal', _rupiah.format(order.subtotal)),
        if (order.discount > 0)
          _row('Diskon', '- ${_rupiah.format(order.discount)}'),
        _row('TOTAL', _rupiah.format(order.total), bold: true, big: true),
        pw.SizedBox(height: 4),
        _divider(),

        // Bayar / sisa
        _row('Dibayar', _rupiah.format(order.totalPaid)),
        _row(
          order.remaining > 0 ? 'Sisa Tagihan' : 'LUNAS',
          _rupiah.format(order.remaining.abs()),
          bold: true,
        ),
        pw.SizedBox(height: 8),

        // Footer
        pw.Center(
          child: pw.Text(
            'Terima kasih atas kepercayaan Anda',
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Simpan nota ini sebagai bukti pengambilan',
            style: const pw.TextStyle(fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  pw.Widget _row(String label, String value, {bool bold = false, bool big = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: big ? 10 : 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: big ? 10 : 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _divider() {
    return pw.Container(
      height: 0.5,
      color: PdfColors.grey600,
    );
  }

  /// Drop trailing .0 from quantities (e.g. 2.0 → "2", 2.5 → "2,5").
  String _fmtQty(double q) {
    if (q == q.truncateToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(1).replaceAll('.', ',');
  }
}
