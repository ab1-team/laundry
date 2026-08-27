import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/format/compact_currency.dart';

void main() {
  test('formats small values without a decimal abbreviation', () {
    expect(formatRupiahShort(0), 'Rp 0');
    expect(formatRupiahShort(999), 'Rp 999');
  });

  test('formats thousands with one decimal when needed', () {
    expect(formatRupiahShort(1000), 'Rp 1k');
    expect(formatRupiahShort(1500), 'Rp 1,5k');
  });

  test('formats millions and billions', () {
    expect(formatRupiahShort(1_500_000), 'Rp 1,5jt');
    expect(formatRupiahShort(10_000_000), 'Rp 10jt');
    expect(formatRupiahShort(2_250_000_000), 'Rp 2,3M');
  });

  test('preserves negative sign and supports custom prefix', () {
    expect(formatRupiahShort(-1500), '-Rp 1,5k');
    expect(formatRupiahShort(12500, prefix: 'IDR '), 'IDR 12,5k');
  });
}
