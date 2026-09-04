import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/order_model.dart';

/// Generates the customer-facing receipt (nota) PDF for an order.
///
/// Output is sized for an 80mm thermal printer (~226pt wide). Classic
/// Indonesian thermal layout: centered kop, meta rows, item lines,
/// totals, and tenant-branded footer. All text uses monospace
/// (Courier) for a thermal-printer look.
class ReceiptPdfService {
  static const double _thermalWidthPt = 80 * 2.835;

  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  Future<Uint8List> build({
    required OrderModel order,
    required Map<String, dynamic> tenant,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _thermalWidthPt,
          double.infinity,
          marginAll: 8,
        ),
        build: (ctx) => _content(order, tenant),
      ),
    );
    return doc.save();
  }

  pw.Widget _content(OrderModel order, Map<String, dynamic> tenant) {
    final tenantName = (tenant['name'] as String?)?.trim();
    final hasTenantName = tenantName != null && tenantName.isNotEmpty;
    final displayName = hasTenantName ? tenantName : 'LAUNDRY';
    final tenantAddress = (tenant['address'] as String?)?.trim();
    final tenantCity = (tenant['city'] as String?)?.trim();
    final tenantPhone = (tenant['phone'] as String?)?.trim();

    final hasAddress = tenantAddress != null && tenantAddress.isNotEmpty;
    final hasCity = tenantCity != null && tenantCity.isNotEmpty;
    final hasPhone = tenantPhone != null && tenantPhone.isNotEmpty;

    String? alamatLine;
    if (hasAddress || hasCity) {
      if (hasAddress && hasCity) {
        alamatLine = 'Alamat : $tenantAddress, $tenantCity';
      } else if (hasAddress) {
        alamatLine = 'Alamat : $tenantAddress';
      } else {
        alamatLine = 'Alamat : $tenantCity';
      }
    }

    final thanksLine = hasTenantName
        ? 'Terima kasih telah menjadi pelanggan setia "$tenantName"'
        : 'Terima kasih telah menjadi pelanggan setia kami';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Text(
            displayName,
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (alamatLine != null)
          pw.Center(
            child: pw.Text(
              alamatLine,
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (hasPhone)
          pw.Center(
            child: pw.Text(
              'Telp : $tenantPhone',
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        pw.SizedBox(height: 6),
        _solidDivider(),
        pw.SizedBox(height: 4),
        _row('No', order.ticketNumber),
        _row('Tanggal', _dateTime.format(order.createdAt)),
        if (order.customerName?.isNotEmpty == true)
          _row('Pelanggan', order.customerName!),
        if (order.customerPhone?.isNotEmpty == true)
          _row('HP', order.customerPhone!),
        if (order.cashier?.isNotEmpty == true)
          _row('Kasir', order.cashier!),
        pw.SizedBox(height: 4),
        _dashedDivider(),
        pw.SizedBox(height: 4),
        ...order.items.map(
          (it) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  it.serviceName,
                  style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8),
                ),
                pw.Row(
                  children: [
                    pw.Text(
                      '${_fmtQty(it.qty)} ${it.unit} x ${_rupiah.format(it.price)}',
                      style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      _rupiah.format(it.subtotal),
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
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
        _dashedDivider(),
        pw.SizedBox(height: 4),
        _row('Subtotal', _rupiah.format(order.subtotal)),
        if (order.discount > 0)
          _row('Diskon', '- ${_rupiah.format(order.discount)}'),
        _row('TOTAL', _rupiah.format(order.total), bold: true, big: true),
        pw.SizedBox(height: 4),
        _dashedDivider(),
        pw.SizedBox(height: 4),
        _row('Dibayar', _rupiah.format(order.totalPaid)),
        if (order.remaining > 0)
          _row('Sisa', _rupiah.format(order.remaining), bold: true)
        else
          _row('LUNAS', _rupiah.format(order.remaining.abs()), bold: true),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            thanksLine,
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 4),
        _dashedDivider(),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Komplain maks 1x24 jam setelah barang diambil',
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Dengan membawa struk ini',
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 4),
        _dashedDivider(),
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
              font: pw.Font.courier(),
              fontSize: big ? 10 : 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: big ? 10 : 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _solidDivider() {
    return pw.Divider(
      thickness: 0.7,
      color: PdfColors.black,
      borderStyle: pw.BorderStyle.solid,
    );
  }

  pw.Widget _dashedDivider() {
    return pw.Divider(
      thickness: 0.5,
      color: PdfColors.black,
      borderStyle: pw.BorderStyle.dashed,
    );
  }

  String _fmtQty(double q) {
    if (q == q.truncateToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(1).replaceAll('.', ',');
  }
}
