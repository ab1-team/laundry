import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TestDioAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  TestDioAdapter(this.handler);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }
}

ResponseBody jsonResponse(
  Object? body, {
  int statusCode = 200,
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(
    body == null ? '' : jsonEncode(body),
    statusCode,
    headers: {
      ...headers,
      'content-type': ['application/json'],
    },
  );
}
