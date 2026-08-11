import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

/// Singleton Dio client with auth token interceptor.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _dio = _build();

  Dio get dio => _dio;

  Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.httpTimeout,
      receiveTimeout: AppConfig.httpTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (status) {
        // Accept semua status (termasuk 5xx) supaya body response sampai ke
        // caller via response.data. Backend bisa return 502 untuk upstream
        // gateway error (mis. workflow n8n belum ready) dengan body JSON
        // berisi pesan jelas — interceptor onResponse di bawah extract
        // `data.message` jadi ApiException agar UI bisa tampilkan.
        //
        // Sebelumnya pakai `status < 500` — 502 ditolak Dio otomatis dengan
        // `DioException [bad response]: null` (body tidak ter-parse), UI cuma
        // lihat pesan generic tanpa diagnosa.
        return status != null;
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.instance.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final statusCode = response.statusCode ?? 200;
        final data = response.data;
        final isHttpError = statusCode >= 400;
        final isLogicError = data is Map && data['success'] == false;

        if (isHttpError || isLogicError) {
          String message = 'Request failed ($statusCode)';
          Map<String, dynamic>? errors;

          if (data is Map) {
            final rawMsg = data['message']?.toString() ??
                data['error']?.toString() ??
                data['detail']?.toString();
            if (rawMsg != null && rawMsg.trim().isNotEmpty) {
              message = rawMsg.trim();
            }
            if (data['errors'] is Map) {
              errors = Map<String, dynamic>.from(data['errors'] as Map);
            }
          } else if (data is String && data.trim().isNotEmpty) {
            final clean = data.replaceAll(RegExp(r'<[^>]*>'), '').trim();
            if (clean.isNotEmpty) {
              message = clean.length > 200 ? '${clean.substring(0, 200)}...' : clean;
            }
          }

          handler.reject(DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: ApiException(
              message,
              statusCode: statusCode,
              errors: errors,
            ),
          ));
          return;
        }
        handler.next(response);
      },
      onError: (err, handler) {
        final apiError = err.error is ApiException
            ? err.error as ApiException
            : ApiException(
                err.message ?? 'Network error',
                statusCode: err.response?.statusCode,
              );
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: apiError,
        ));
      },
    ));

    return dio;
  }
}
