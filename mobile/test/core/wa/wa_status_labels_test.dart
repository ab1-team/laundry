import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/wa/wa_status_labels.dart';

void main() {
  test('status lifecycle has stable keys and labels', () {
    expect(WaStatusLabels.all.map((s) => s.key), [
      'masuk', 'dicuci', 'selesai', 'diambil', 'dibatalkan',
    ]);
    expect(WaStatusLabels.byKey['dicuci'], 'Sedang Dicuci');
  });

  test('exposes all documented template variables', () {
    expect(WaStatusLabels.variables.map((v) => v.token), containsAll([
      '{tenant_name}', '{ticket_number}', '{status_label}', '{order_total}',
    ]));
  });

  test('renders known variables and leaves unknown tokens literal', () {
    final vars = WaSampleVars.forStatus('selesai', tenantName: 'Clean Co');
    expect(renderWaPreview('{tenant_name}: {status_label} {unknown}', vars),
        'Clean Co: Selesai {unknown}');
  });

  test('falls back to raw status key', () {
    expect(WaSampleVars.forStatus('custom')['{status_label}'], 'custom');
  });
}
