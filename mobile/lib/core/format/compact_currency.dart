/// Compact currency formatter untuk card dashboard / stat kecil.
///
/// Output ringkas dalam bahasa Indonesia:
///   1.500        → "Rp 1,5k"
///   10.000       → "Rp 10k"
///   150.000      → "Rp 150k"
///   1.500.000    → "Rp 1,5jt"
///   10.000.000   → "Rp 10jt"
///   1.500.000.000 → "Rp 1,5M"
///
/// Presisi: 1 desimal, dibulatkan dari koma desimal lokal (id_ID
/// pakai koma). Di bawah 1.000 tampil full agar tetap terbaca.
///
/// Pakai di StatCard yang space-nya sempit (Piutang, dll) supaya
/// nominal panjang tidak overflow / membuat card terlalu lebar.
String formatRupiahShort(num value, {String prefix = 'Rp '}) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';

  if (abs < 1000) {
    return '$sign$prefix${abs.toStringAsFixed(0)}';
  }

  final String compact;
  if (abs < 1_000_000) {
    // Ribuan → "k"
    compact = '${_formatDecimal(abs / 1000)}k';
  } else if (abs < 1_000_000_000) {
    // Jutaan → "jt"
    compact = '${_formatDecimal(abs / 1_000_000)}jt';
  } else {
    // Miliaran → "M"
    compact = '${_formatDecimal(abs / 1_000_000_000)}M';
  }

  return '$sign$prefix$compact';
}

String _formatDecimal(double n) {
  // Bulatkan ke 1 desimal; hilangkan ".0" kalau bulat.
  final rounded = (n * 10).round() / 10;
  if (rounded == rounded.truncate()) {
    return rounded.toStringAsFixed(0);
  }
  // Pakai koma sebagai pemisah desimal (id_ID locale).
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}