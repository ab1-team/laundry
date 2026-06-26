import 'dart:io';

import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Extract a user-friendly message from any exception thrown by the
/// network layer. Falls back to a generic "Network error" string when
/// no message can be recovered.
///
/// Resolution order:
/// 1. `ApiException.message` — cleanest, comes straight from the backend.
/// 2. `DioException.error` if it wraps an `ApiException` (the way our
///    `ApiClient` interceptor rejects responses).
/// 3. `DioException.message` for transport errors (timeout, no connection).
/// 4. `SocketException.message` for low-level network failures.
/// 5. Fallback to a localized generic string.
String extractApiMessage(Object error, {String fallback = 'Terjadi kesalahan. Coba lagi.'}) {
  if (error is ApiException) return error.message;

  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return inner.message;
    final msg = error.message;
    if (msg != null && msg.isNotEmpty) return msg;
  }

  if (error is SocketException) {
    return 'Tidak ada koneksi internet';
  }

  return fallback;
}