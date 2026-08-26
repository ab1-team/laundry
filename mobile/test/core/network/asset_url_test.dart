import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/config/app_config.dart';
import 'package:laundry/core/network/asset_url.dart';

void main() {
  test('returns empty for null or blank paths', () {
    expect(resolveAssetUrl(null), '');
    expect(resolveAssetUrl(''), '');
  });

  test('keeps absolute URLs unchanged', () {
    expect(resolveAssetUrl('https://cdn.example.com/a.png'), 'https://cdn.example.com/a.png');
    expect(resolveAssetUrl('http://example.com/b.png'), 'http://example.com/b.png');
  });

  test('converts API base URL to origin for relative assets', () {
    final origin = Uri.parse(AppConfig.apiBaseUrl).origin;
    expect(resolveAssetUrl('/storage/logo.png'), '$origin/storage/logo.png');
    expect(resolveAssetUrl('storage/logo.png'), '$origin/storage/logo.png');
  });
}
