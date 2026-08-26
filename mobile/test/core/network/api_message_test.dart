import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/network/api_exception.dart';
import 'package:laundry/core/network/api_message.dart';

void main() {
  final requestOptions = RequestOptions(path: '/');

  test('prefers direct ApiException message', () {
    expect(extractApiMessage(ApiException('Direct')), 'Direct');
  });

  test('unwraps DioException containing ApiException', () {
    final dioError = DioException(requestOptions: requestOptions, error: ApiException('Wrapped'));
    expect(extractApiMessage(dioError), 'Wrapped');
  });

  test('uses DioException transport message before socket fallback', () {
    final dioError = DioException(requestOptions: requestOptions, message: 'connection timeout');
    expect(extractApiMessage(dioError), 'connection timeout');
    expect(extractApiMessage(const SocketException('offline')), 'Tidak ada koneksi internet');
  });

  test('returns custom fallback for unrelated errors', () {
    expect(extractApiMessage(StateError('bad'), fallback: 'Coba lagi'), 'Coba lagi');
  });
}
