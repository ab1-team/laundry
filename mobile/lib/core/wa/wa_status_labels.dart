/// Label status order + daftar variabel template WA — single source of truth
/// untuk mobile. HARUS sinkron dengan backend `OrderService::statusLabel()` dan
/// `EvolutionService::DEFAULT_TEMPLATES`. Saat tambah/ubah, update kedua sisi.
///
/// Token di `{name}` akan di-substitusi backend via `EvolutionService::renderTemplate()`
/// (strtr). Unknown token left literal — jadi jangan salah ketik.
class WaStatusLabels {
  const WaStatusLabels._();

  /// 5 status order — urutan sesuai lifecycle laundry.
  static const List<WaStatus> all = [
    WaStatus(key: 'masuk', label: 'Diterima'),
    WaStatus(key: 'dicuci', label: 'Sedang Dicuci'),
    WaStatus(key: 'selesai', label: 'Selesai'),
    WaStatus(key: 'diambil', label: 'Sudah Diambil'),
    WaStatus(key: 'dibatalkan', label: 'Dibatalkan'),
  ];

  /// Lookup map untuk resolve label by key — dipakai preview render dan
  /// display nama di header tile.
  static const Map<String, String> byKey = {
    'masuk': 'Diterima',
    'dicuci': 'Sedang Dicuci',
    'selesai': 'Selesai',
    'diambil': 'Sudah Diambil',
    'dibatalkan': 'Dibatalkan',
  };

  /// Variabel yang tersedia di semua template. Display label Indonesia
  /// untuk chip, token persis sama dengan yang backend cari via strtr.
  static const List<WaVariable> variables = [
    WaVariable(token: '{tenant_name}', label: 'Nama Tenant'),
    WaVariable(token: '{ticket_number}', label: 'No. Tiket'),
    WaVariable(token: '{status_label}', label: 'Label Status'),
    WaVariable(token: '{customer_name}', label: 'Nama Customer'),
    WaVariable(token: '{notes}', label: 'Catatan'),
    WaVariable(token: '{order_total}', label: 'Total (Rp)'),
    WaVariable(token: '{estimated_ready_at}', label: 'Estimasi Selesai'),
  ];
}

/// Status order + label UI-nya.
class WaStatus {
  const WaStatus({required this.key, required this.label});
  final String key;
  final String label;
}

/// Variable template WA — `token` ({tenant_name}) yang di-substitusi backend,
/// `label` (Nama Tenant) yang ditampilkan di chip UI mobile.
class WaVariable {
  const WaVariable({required this.token, required this.label});
  final String token;
  final String label;
}

/// Sample data untuk live preview template di mobile — supaya user lihat
/// hasil render sebelum save. Update kalau backend tambah variabel baru.
class WaSampleVars {
  const WaSampleVars._();

  /// Sample $vars per status — name/ticket/total generic, `status_label`
  /// di-map per status.
  static Map<String, String> forStatus(String statusKey, {String tenantName = 'Laundry Anda'}) {
    final label = WaStatusLabels.byKey[statusKey] ?? statusKey;
    return {
      '{tenant_name}': tenantName,
      '{ticket_number}': 'LND-20260716-0001',
      '{status_label}': label,
      '{customer_name}': 'Budi Santoso',
      '{notes}': 'Baju ada yang luntur, mohon dicek saat ambil.',
      '{order_total}': 'Rp 50.000',
      '{estimated_ready_at}': '17 Jul 2026 18:00',
    };
  }
}

/// Preview renderer — pakai strtr-style substitution manual di Dart.
/// Sama dengan backend `renderTemplate`: unknown token left literal.
String renderWaPreview(String template, Map<String, String> vars) {
  var out = template;
  vars.forEach((token, value) => out = out.replaceAll(token, value));
  return out;
}
