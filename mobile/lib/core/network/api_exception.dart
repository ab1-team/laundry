/// API exception wrapper — mirrors backend `{success, message, errors}` shape.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden    => statusCode == 403;
  bool get isNotFound     => statusCode == 404;
  bool get isValidation   => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
