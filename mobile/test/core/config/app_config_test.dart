import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/config/app_config.dart';

void main() {
  test('exposes stable application configuration', () {
    expect(AppConfig.apiBaseUrl, contains('/api/v1'));
    expect(AppConfig.appName, isNotEmpty);
    expect(AppConfig.httpTimeout, const Duration(seconds: 30));
  });
}
