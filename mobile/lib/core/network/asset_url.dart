import '../config/app_config.dart';

/// Resolves a backend asset URL returned by the API into an absolute URL
/// the device can fetch.
///
/// The API returns relative paths like `/storage/tenants/logos/x.png`
/// (see backend `TenantResource::logo_url`). For the device to actually
/// download the image, the path must be combined with the API host —
/// `apiBaseUrl` is `http://host:port/api/v1`, so we strip the trailing
/// `/api/v1` and prepend the remainder.
///
/// If [raw] is already absolute (`http://...` / `https://...`), it's
/// returned unchanged.
String resolveAssetUrl(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

  final base = Uri.parse(AppConfig.apiBaseUrl);
  final origin = '${base.scheme}://${base.authority}';
  if (raw.startsWith('/')) return '$origin$raw';
  return '$origin/$raw';
}
