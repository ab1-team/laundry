import '../../../core/network/api_client.dart';

/// WhatsApp gateway (Evolution API) repository.
///
/// Backend endpoints:
/// - `GET  /api/v1/wa-pairing` (opsional, kalau ada) → cek status koneksi
/// - `POST /api/v1/wa-pairing`            → minta pairing code
/// - `PUT  /api/v1/settings/tenant`       → set wa_settings (enabled, instance, notify_on)
class WhatsAppRepository {
  WhatsAppRepository(this._api);
  final ApiClient _api;

  /// Response shape dari POST /wa-pairing:
  /// { pairing_code: "WZYEH1YY", instance: "...", expires_in: 60 }
  Future<Map<String, dynamic>> requestPairingCode(String number) async {
    final res = await _api.dio.post(
      '/wa-pairing',
      data: {'number': number},
    );
    return (res.data as Map)['data'] as Map<String, dynamic>;
  }

  /// Reset koneksi WA — logout sesi di Evolution server + clear enabled flag.
  /// Setelah ini, panggil [requestPairingCode] untuk dapat kode pairing baru.
  /// Response: { instance: "LaundryAja-..." }
  Future<Map<String, dynamic>> resetConnection() async {
    final res = await _api.dio.post('/wa-pairing/reset');
    return (res.data as Map)['data'] as Map<String, dynamic>;
  }

  /// Sinkron flag `enabled` di backend dengan state real Evolution.
  /// Pakai untuk handle skenario owner re-pair WA di HP tanpa lewat
  /// endpoint /wa-pairing (langsung di WA → Linked Devices).
  /// Response: { state: "open"|"close"|null, enabled: bool, instance: "..." }
  Future<Map<String, dynamic>> fetchConnectionState() async {
    final res = await _api.dio.get('/wa-connection-state');
    return (res.data as Map)['data'] as Map<String, dynamic>;
  }

  /// Update wa_settings. Payload: { enabled, instance, notify_on, owner_number? }
  Future<Map<String, dynamic>> updateWaSettings(Map<String, dynamic> waSettings) async {
    final res = await _api.dio.put(
      '/settings/tenant',
      data: {'wa_settings': waSettings},
    );
    return (res.data as Map)['data'] as Map<String, dynamic>;
  }

  /// Ambil wa_settings dari tenant row saat ini.
  /// Tenant row lengkap dari `getTenant()` — method ini cuma helper extract.
  Map<String, dynamic>? extractWaSettings(Map<String, dynamic> tenant) {
    final raw = tenant['wa_settings'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}
