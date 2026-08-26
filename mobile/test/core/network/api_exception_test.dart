import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/network/api_exception.dart';

void main() {
  test('maps status helpers and readable representation', () {
    final error = ApiException('Validation failed', statusCode: 422);
    expect(error.isValidation, isTrue);
    expect(error.isUnauthorized, isFalse);
    expect(error.toString(), 'ApiException(422): Validation failed');
  });

  test('supports validation errors and missing status', () {
    final error = ApiException(
      'Invalid input',
      errors: {'email': ['required']},
    );
    expect(error.statusCode, isNull);
    expect(error.errors, {'email': ['required']});
  });
}
