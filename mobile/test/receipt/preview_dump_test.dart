import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:laundry/features/orders/data/order_model.dart';
import 'package:laundry/features/orders/data/receipt_pdf_service.dart';

/// Manual visual-preview dump (bukan assertion test): menulis PDF preview
/// ke /root/tasks/laundry-receipt-branding/ untuk dirender jadi gambar.
/// Skip di CI — hanya jalan kalau env HERMES_PREVIEW_OUT diset.
void main() {
  test('dump receipt preview pdf', () async {
    final out = Platform.environment['HERMES_PREVIEW_OUT'];
    if (out == null || out.isEmpty) {
      return; // no-op di CI
    }
    final order = OrderModel(
      id: 42,
      ticketNumber: 'LJA-20260904-0042',
      customerId: 7,
      customerName: 'Ibu Sari Wulandari',
      customerPhone: '0812-2718-3345',
      status: 'selesai',
      subtotal: 42000,
      discount: 2000,
      total: 40000,
      totalPaid: 40000,
      remaining: 0,
      createdAt: DateTime(2026, 9, 4, 10, 15),
      items: [
        OrderItemModel(
          id: 1,
          serviceId: 3,
          serviceName: 'Cuci Kering Setrika',
          unit: 'kg',
          price: 7000.0,
          qty: 4.0,
          subtotal: 28000.0,
        ),
        OrderItemModel(
          id: 2,
          serviceId: 5,
          serviceName: 'Cuci Sepatu',
          unit: 'pasang',
          price: 14000.0,
          qty: 1.0,
          subtotal: 14000.0,
        ),
      ],
      cashier: 'Fii',
    );

    final tenant = {
      'name': 'NUSA LOUNDRY EXPRES',
      'address': 'JL.jendral Soedirman no.17A Nusawungu',
      'city': 'Banjarnegara',
      'phone': '0821-3456-7890',
      'logo_url': '',
    };

    final bytes = await ReceiptPdfService().build(order: order, tenant: tenant);
    File('$out/preview-tenant.pdf').writeAsBytesSync(bytes);

    final minimal = await ReceiptPdfService().build(order: order, tenant: const {});
    File('$out/preview-minimal.pdf').writeAsBytesSync(minimal);

    expect(bytes.isNotEmpty, isTrue);
  });
}
