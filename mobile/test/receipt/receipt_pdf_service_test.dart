import 'dart:io';
import 'dart:typed_data';

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

    test('build degrades gracefully when logo URL is unreachable', () async {
      final service = ReceiptPdfService();
      final order = buildOrder();
      final tenant = {
        'name': 'Nusa Laundry',
        'address': 'Jl. Merdeka No. 10',
        'city': 'Jakarta',
        'phone': '08123456789',
        'logo_url': 'http://127.0.0.1:1/unreachable.png',
      };

      final stopwatch = Stopwatch()..start();
      final bytes = await service.build(order: order, tenant: tenant);
      stopwatch.stop();

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
    });

    test('build renders tenant logo when logo is served successfully via HTTP', () async {
      final pngBytes = Uint8List.fromList(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(pngBytes);
        request.response.close();
      });

      try {
        final service = ReceiptPdfService();
        final order = buildOrder(cashier: 'Kasir B');
        final tenant = {
          'name': 'Nusa Laundry',
          'address': 'Jl. Merdeka No. 10',
          'city': 'Jakarta',
          'phone': '08123456789',
          'logo_url': 'http://${server.address.host}:${server.port}/logo.png',
        };

        final bytes = await service.build(order: order, tenant: tenant);

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      } finally {
        await server.close(force: true);
      }
    });

    test('build falls back to logo_path when logo_url is absent or empty', () async {
      final pngBytes = Uint8List.fromList(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(pngBytes);
        request.response.close();
      });

      try {
        final service = ReceiptPdfService();
        final order = buildOrder(cashier: 'Kasir C');
        final tenant = {
          'name': 'Nusa Laundry',
          'address': 'Jl. Merdeka No. 10',
          'city': 'Jakarta',
          'phone': '08123456789',
          'logo_url': '',
          'logo_path': 'http://${server.address.host}:${server.port}/fallback_logo.png',
        };

        final bytes = await service.build(order: order, tenant: tenant);

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      } finally {
        await server.close(force: true);
      }
    });
  });
}
