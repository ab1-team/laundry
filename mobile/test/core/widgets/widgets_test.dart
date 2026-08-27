import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry/core/widgets/app_button.dart';
import 'package:laundry/core/widgets/app_text_field.dart';
import 'package:laundry/core/widgets/order_summary_card.dart';
import 'package:laundry/core/widgets/payment_method_card.dart';
import 'package:laundry/core/widgets/stat_card.dart';
import 'package:laundry/core/widgets/status_chip.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('status chip renders every lifecycle label', (tester) async {
    const statuses = [
      (OrderStatus.masuk, 'Menunggu'),
      (OrderStatus.dicuci, 'Proses'),
      (OrderStatus.selesai, 'Selesai'),
      (OrderStatus.diambil, 'Diambil'),
      (OrderStatus.dibatalkan, 'Batal'),
    ];
    await tester.pumpWidget(host(
      Column(children: [for (final item in statuses) StatusChip(status: item.$1)]),
    ));
    for (final item in statuses) {
      expect(find.text(item.$2), findsOneWidget);
      expect(OrderStatusX.fromString(item.$1.name), item.$1);
    }
  });

  testWidgets('app button handles taps, icons, and loading state', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppButton(
      label: 'Save',
      icon: Icons.save,
      onPressed: () => taps++,
    )));
    expect(taps, 0);
    await tester.tap(find.text('Save'));
    expect(taps, 1);

    await tester.pumpWidget(host(const AppButton(label: 'Save', loading: true, onPressed: null)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('app text field edits and disables', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(host(AppTextField(controller: controller, label: 'Name', hint: 'Your name')));
    await tester.enterText(find.byType(TextField), 'Budi');
    expect(controller.text, 'Budi');

    await tester.pumpWidget(host(const AppTextField(label: 'Disabled', enabled: false)));
    expect(tester.takeException(), isNull);
  });

  test('currency formatter groups digits while preserving raw digits', () {
    final formatter = _ThousandsSeparatorFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '1500000'),
    );
    expect(result.text, '1.500.000');
  });

  testWidgets('stat card renders variants and optional footer text', (tester) async {
    await tester.pumpWidget(host(const Column(children: [
      StatCard(title: 'Orders', value: '24', unit: 'orders'),
      StatCard(title: 'Revenue', value: 'Rp 10jt', variant: StatCardVariant.primary, subtitle: 'this month'),
      StatCard(title: 'Debt', value: 'Rp 2jt', variant: StatCardVariant.attention),
    ])));
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Rp 10jt'), findsOneWidget);
    expect(find.text('this month'), findsOneWidget);
    expect(find.byIcon(Icons.local_laundry_service), findsOneWidget);
  });

  testWidgets('order summary card displays details and segments', (tester) async {
    var tapped = false;
    final segments = buildOrderSegments([
      _Item(qty: 5, unit: 'kg', serviceName: 'Cuci Kiloan'),
      _Item(qty: 2.5, unit: 'pcs', serviceName: 'Sepatu'),
      _Item(qty: 1, unit: 'pcs', serviceName: 'Selimut'),
    ], maxSegments: 2);
    await tester.pumpWidget(host(OrderSummaryCard(
      ticketNumber: '#TRX-1',
      customerName: 'Budi',
      status: OrderStatus.selesai,
      totalLabel: 'Rp 70.000',
      segments: segments,
      createdAt: DateTime(2026, 7, 16, 18),
      onTap: () => tapped = true,
    )));
    expect(find.text('#TRX-1'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Rp 70.000'), findsOneWidget);
    expect(find.text('+ 1 layanan lain'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    await tester.tap(find.text('Budi'));
    expect(tapped, isTrue);
  });

  testWidgets('payment method card honors selection and disabled state', (tester) async {
    var selectedTaps = 0;
    var disabledTaps = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        PaymentMethodCard(
          label: 'Cash',
          icon: Icons.payments,
          selected: true,
          onTap: () => selectedTaps++,
        ),
        PaymentMethodCard(
          label: 'Transfer',
          icon: Icons.account_balance,
          selected: false,
          disabled: true,
          disabledHint: 'Segera hadir',
          onTap: () => disabledTaps++,
        ),
      ]),
    ));
    expect(selectedTaps, 0);
    await tester.tap(find.text('Cash'));
    expect(selectedTaps, 1);
    await tester.tap(find.text('Transfer'));
    expect(disabledTaps, 0);
    expect(find.text('Segera hadir'), findsOneWidget);
  });
}

class _Item implements OrderItemLike {
  const _Item({required this.qty, required this.unit, required this.serviceName});
  @override
  final double qty;
  @override
  final String unit;
  @override
  final String serviceName;
  @override
  String? get categoryIcon => null;
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return TextEditingValue(text: grouped, selection: TextSelection.collapsed(offset: grouped.length));
  }
}
