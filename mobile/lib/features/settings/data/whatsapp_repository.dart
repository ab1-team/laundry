import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// WhatsApp gateway (Evolution API) repository.
///
/// Backend endpoints:
/// - `POST /api/v1/wa-pairing`            → minta pairing code
/// - `POST /api/v1/wa-pairing/reset`      → logout sesi WA di HP owner
/// - `GET  /api/v1/wa-connection-state`   → sinkron enabled vs state real
/// - `PUT  /api/v1/settings/tenant`       → set wa_settings
///                                          (enabled, instance, notify_on, templates)
class WhatsAppRepository {
  WhatsAppRepository(this._api);
  final ApiClient _api;

  /// Extract `{success, message, data}` → `data` as Map<String, dynamic>.
  ///
  /// SEBELUMNYA pakai pattern `(res.data as Map)['data'] as Map<String, dynamic>`
  /// yang throw raw TypeError `Null is not a subtype of Map<String, dynamic>`
  /// ketika backend (atau interceptor upstream) mengirim body tanpa field
  /// `data`. Snack bar user cuma lihat pesan generic tanpa endpoint info.
  ///
  /// Sekarang pakai helper ini: kalau body tidak sesuai shape sukses
  /// `{success, message, data}`, lempar [ApiException] dengan path + status
  /// supaya user tahu endpoint mana yang return shape aneh dan tim bisa
  /// debug dengan cepat.
  Map<String, dynamic> _unwrapData(Response<dynamic> res, String endpoint) {
    final body = res.data;
    if (body is! Map) {
      throw ApiException(
        'Response dari $endpoint bukan JSON object',
        statusCode: res.statusCode,
      );
    }
    final data = body['data'];
    if (data is! Map) {
      throw ApiException(
        'Response dari $endpoint tidak punya field "data" '
        '(success=${body['success']}, message=${body['message'] ?? '(none)'})',
        statusCode: res.statusCode,
      );
    }
    return Map<String, dynamic>.from(data);
  }

  /// Response shape dari POST /wa-pairing:
  /// { pairing_code: "WZYEH1YY", instance: "...", expires_in: 60 }
  Future<Map<String, dynamic>> requestPairingCode(String number) async {
    final res = await _api.dio.post(
      '/wa-pairing',
      data: {'number': number},
    );
    return _unwrapData(res, 'POST /wa-pairing');
  }

  /// Mintakan pairing code BARU untuk instance yang sudah ada. Tidak
  /// membuat instance baru — beda dari [requestPairingCode] yang
  /// create-instance. Pakai saat pairing code sebelumnya expire (60s)
  /// atau sudah terpakai.
  ///
  /// Response shape: sama dengan /wa-pairing — `{instance: {name, status,
  /// qr, pairingCode, state}}`. Kalau n8n tidak return `pairingCode`
  /// di state-poll, response tetap di-forward dan mobile fallback pakai
  /// `qr` dari `instance.qr` untuk scan di WA.
  Future<Map<String, dynamic>> regeneratePairingCode() async {
    final res = await _api.dio.post('/wa-pairing/regenerate');
    return _unwrapData(res, 'POST /wa-pairing/regenerate');
  }

  /// Reset koneksi WA — hapus instance di n8n server + clear enabled flag.
  /// Setelah ini, panggil [requestPairingCode] untuk dapat kode pairing baru.
  /// Response: { instance: "LaundryAja-..." }
  Future<Map<String, dynamic>> resetConnection() async {
    final res = await _api.dio.post('/wa-pairing/reset');
    return _unwrapData(res, 'POST /wa-pairing/reset');
  }

  /// Sinkron flag `enabled` di backend dengan state real Evolution.
  /// Pakai untuk handle skenario owner re-pair WA di HP tanpa lewat
  /// endpoint /wa-pairing (langsung di WA → Linked Devices).
  /// Response: { state: "open"|"close"|null, enabled: bool, instance: "..." }
  Future<Map<String, dynamic>> fetchConnectionState() async {
    final res = await _api.dio.get('/wa-connection-state');
    return _unwrapData(res, 'GET /wa-connection-state');
  }

  /// Update wa_settings. Payload: { enabled, instance, notify_on, owner_number? }
  Future<Map<String, dynamic>> updateWaSettings(Map<String, dynamic> waSettings) async {
    final res = await _api.dio.put(
      '/settings/tenant',
      data: {'wa_settings': waSettings},
    );
    return _unwrapData(res, 'PUT /settings/tenant');
  }

  /// Ambil wa_settings dari tenant row saat ini.
  /// Tenant row lengkap dari `getTenant()` — method ini cuma helper extract.
  /// Return null kalau wa_settings belum pernah diset (DB null / payload null).
  Map<String, dynamic>? extractWaSettings(Map<String, dynamic> tenant) {
    final raw = tenant['wa_settings'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}
