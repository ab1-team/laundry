import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry/features/orders/data/order_model.dart';
import 'package:laundry/features/orders/data/receipt_pdf_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ReceiptPdfService', () {
    OrderModel buildOrder({String? cashier}) {
      return OrderModel(
        id: 1,
        ticketNumber: 'T-001',
        customerId: 10,
        customerName: 'Budi',
        customerPhone: '+628123456789',
        status: 'masuk',
        subtotal: 15000,
        discount: 1000,
        total: 14000,
        createdAt: DateTime(2026, 7, 16, 10, 30),
        totalPaid: 5000,
        remaining: 9000,
        cashier: cashier,
        items: [
          OrderItemModel(
            id: 20,
            serviceId: 8,
            serviceName: 'Cuci Kering',
            unit: 'kg',
            price: 7000,
            qty: 2,
            subtotal: 14000,
          ),
        ],
      );
    }

    test('build with full tenant map produces valid PDF', () async {
      final service = ReceiptPdfService();
      final order = buildOrder(cashier: 'Kasir A');
      final tenant = {
        'name': 'Nusa Laundry',
        'address': 'Jl. Merdeka No. 10',
        'city': 'Jakarta',
        'phone': '08123456789',
      };

      final bytes = await service.build(order: order, tenant: tenant);

      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });

    test('build with empty tenant map falls back and still produces valid PDF', () async {
      final service = ReceiptPdfService();
      final order = buildOrder();
      final tenant = <String, dynamic>{};

      final bytes = await service.build(order: order, tenant: tenant);

      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });

    test('build does not throw for minimal tenant and order', () async {
      final service = ReceiptPdfService();
      final order = OrderModel(
        id: 2,
        ticketNumber: 'T-002',
        customerId: 11,
        status: 'selesai',
        subtotal: 0,
        discount: 0,
        total: 0,
        createdAt: DateTime(2026, 1, 1, 9, 0),
        totalPaid: 0,
        remaining: 0,
        items: [],
      );

      expect(
        () async => service.build(order: order, tenant: const {}),
        returnsNormally,
      );
      final bytes = await service.build(order: order, tenant: const {});
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
