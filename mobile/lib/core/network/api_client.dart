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
      validateStatus: (status) => status != null && status < 500,
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
        // Backend uses {success, message, data, errors}.
        // Treat 4xx as errors for callers.
        final data = response.data;
        if (data is Map && data['success'] == false) {
          handler.reject(DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: ApiException(
              data['message']?.toString() ?? 'Request failed',
              statusCode: response.statusCode,
              errors: data['errors'] is Map<String, dynamic>
                  ? data['errors'] as Map<String, dynamic>
                  : (data['errors'] is Map
                      ? Map<String, dynamic>.from(data['errors'] as Map)
                      : null),
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
