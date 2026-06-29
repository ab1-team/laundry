/// Response shape dari GET /api/v1/app/version.
///
/// `latest_version` & `min_version` diparse ke [Version] sebelum dipakai
/// perbandingan, supaya string "1.2.0" dibanding string bukan angka.
class AppVersionInfo {
  AppVersionInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.apkUrl,
    required this.forceUpdate,
    required this.changelog,
  });

  final Version latestVersion;
  final Version minVersion;
  final String apkUrl;
  final bool forceUpdate;
  final String changelog;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: Version.parse(json['latest_version'] as String),
      minVersion: Version.parse((json['min_version'] as String?) ?? '0.0.0'),
      apkUrl: json['apk_url'] as String,
      forceUpdate: json['force_update'] as bool? ?? false,
      changangelog: (json['changelog'] as String?) ?? '',
    );
  }
}

/// Hasil pemeriksaan versi lokal vs server.
enum UpdateRequirement {
  /// Versi lokal >= latest → tidak ada update.
  none,

  /// Versi lokal < latest, tapi >= min → update opsional.
  optional,

  /// Versi lokal < min, atau server flag force_update → update wajib.
  mandatory,
}

class UpdateCheckResult {
  UpdateCheckResult({required this.requirement, required this.info});
  final UpdateRequirement requirement;
  final AppVersionInfo? info;
}

/// Wrapper tipis di atas `package_info_plus` / hardcoded fallback agar
/// service ini tidak crash kalau package_info_plus belum terpasang.
class CurrentAppVersion {
  CurrentAppVersion({required this.name, required this.code});
  final String name;
  final int code;

  Version get version => Version.parse(name);
}