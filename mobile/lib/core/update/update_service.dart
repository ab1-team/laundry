import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'update_models.dart';
import 'version.dart';

/// Sumber versi aplikasi yang sedang berjalan.
///
/// Class ini adalah model lokal — bukan re-export dari package_info_plus.
/// Dipakai oleh UpdateService untuk komparasi dengan latest_version
/// dari backend. Runtime versionName + versionCode dibaca di main.dart
/// via `package_info_plus` PackageInfo.fromPlatform(), lalu di-inject
/// ke provider scope. Default di sini cuma fallback kalau ProviderScope
/// lupa override (mis. unit test tanpa bootstrap) — bukan sumber
/// kebenaran untuk production.
class PackageInfo {
  const PackageInfo({required this.versionName, required this.versionCode});
  final String versionName;
  final int versionCode;
}

final packageInfoProvider = Provider<PackageInfo>((ref) {
  // Fallback kalau tidak di-override: pakai 0.0.0+0 supaya komparasi
  // selalu trigger update, memaksa user/admin sadar konfigurasi salah.
  // Production path di main.dart SELALU override dengan runtime read.
  return const PackageInfo(versionName: '0.0.0', versionCode: 0);
});

/// Service utama self-update.
///
/// Tanggung jawab:
///   1. Cek versi terbaru ke backend (`/api/v1/app/version`)
///   2. Bandingkan dengan versi lokal → tentukan requirement
///   3. Download APK ke internal storage (bukan Downloads, agar app bisa
///      baca tanpa permission tambahan)
///   4. Trigger package installer via `install_apk` (dipanggil dari UI)
class UpdateService {
  UpdateService(this._dio);

  final Dio _dio;

  /// Cek versi terbaru. Tidak meledak kalau backend belum punya endpoint —
  /// return `UpdateCheckResult.none()` dan UI cukup skip.
  Future<UpdateCheckResult> checkForUpdate(PackageInfo local) async {
    try {
      final res = await _dio.get<dynamic>('/app/version');
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return UpdateCheckResult(
          requirement: UpdateRequirement.none,
          info: null,
        );
      }
      final payload = data['data'];
      if (payload is! Map<String, dynamic>) {
        return UpdateCheckResult(
          requirement: UpdateRequirement.none,
          info: null,
        );
      }

      final info = AppVersionInfo.fromJson(Map<String, dynamic>.from(payload));
      final current = _safeVersion(local.versionName);

      if (info.forceUpdate || current < info.minVersion) {
        return UpdateCheckResult(
          requirement: UpdateRequirement.mandatory,
          info: info,
        );
      }
      if (current < info.latestVersion) {
        return UpdateCheckResult(
          requirement: UpdateRequirement.optional,
          info: info,
        );
      }
      return UpdateCheckResult(requirement: UpdateRequirement.none, info: info);
    } on DioException catch (e) {
      // 4xx/5xx dari backend atau network error → skip update flow.
      // Log supaya developer tahu endpoint-nya hidup atau tidak.
      // ignore: avoid_print
      print('[UpdateService] check failed: ${e.message}');
      return UpdateCheckResult(
        requirement: UpdateRequirement.none,
        info: null,
      );
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('[UpdateService] api error: ${e.message}');
      return UpdateCheckResult(
        requirement: UpdateRequirement.none,
        info: null,
      );
    }
  }

  /// Download APK ke internal storage. `onProgress` dipanggil 0..1.
  /// Return absolute path file untuk diteruskan ke `InstallApk.install`.
  Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/update-${DateTime.now().millisecondsSinceEpoch}.apk');
    await _dio.download(
      url,
      file.path,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );
    return file.path;
  }

  Version _safeVersion(String raw) {
    try {
      return Version.parse(raw.trim().split('+').first);
    } catch (_) {
      return Version.parse('0.0.0');
    }
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(ApiClient.instance.dio);
});