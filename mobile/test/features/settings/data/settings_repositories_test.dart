import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundry/core/network/api_exception.dart';
import 'package:laundry/features/settings/data/password_repository.dart';
import 'package:laundry/features/settings/data/preferences_repository.dart';
import 'package:laundry/features/settings/data/tenant_settings_repository.dart';
import 'package:laundry/features/settings/data/whatsapp_repository.dart';

import '../../../helpers/test_dio_adapter.dart';
import '../../../helpers/secure_storage_test_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secureStorage = SecureStorageTestChannel();
  setUpAll(secureStorage.install);

  late ApiClient apiClient;
  late Object? data;
  late String path;
  late String method;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.values.clear();
    apiClient = ApiClient.instance;
    final adapter = TestDioAdapter((options) async => jsonResponse(null));
    apiClient.dio.httpClientAdapter = adapter;
    data = null;
    path = '';
    method = '';
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      data = options.data;
      path = options.path;
      method = options.method;
      return jsonResponse({'data': {'id': 1}});
    });
  });

  test('password repository sends confirmation payload', () async {
    await PasswordRepository(apiClient).changePassword(current: 'old', next: 'new');
    expect('$method $path', 'PUT /auth/password');
    expect(data, {
      'current_password': 'old',
      'password': 'new',
      'password_confirmation': 'new',
    });
  });

  test('preferences repository persists and clears theme/locale', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = PreferencesRepository(prefs);

    expect(repository.getThemeMode(), ThemeMode.light);
    expect(repository.getLocale(), isNull);
    await repository.setThemeMode(ThemeMode.dark);
    await repository.setLocale(const Locale('en'));
    expect(repository.getThemeMode(), ThemeMode.dark);
    expect(repository.getLocale()?.languageCode, 'en');

    await repository.setLocale(null);
    expect(repository.getLocale(), isNull);
    await repository.setThemeMode(ThemeMode.system);
    expect(repository.getThemeMode(), ThemeMode.system);
  });

  test('tenant settings unwraps success and rejects invalid envelopes', () async {
    final repository = TenantSettingsRepository(apiClient);
    expect(await repository.getTenant(), {'id': 1});

    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async => jsonResponse('oops'));
    await expectLater(repository.getTenant(), throwsA(isA<ApiException>()));
  });

  test('WhatsApp settings calls all endpoints and extracts nested settings', () async {
    final repository = WhatsAppRepository(apiClient);
    await repository.requestPairingCode('+628');
    expect('$method $path', 'POST /wa-pairing');
    expect(data, {'number': '+628'});

    for (final call in [
      repository.regeneratePairingCode,
      repository.resetConnection,
      repository.fetchConnectionState,
    ]) {
      await call();
    }
    expect(path, '/wa-connection-state');

    const waSettings = {'enabled': true};
    await repository.updateWaSettings(waSettings);
    expect(data, {'wa_settings': waSettings});
    expect(repository.extractWaSettings({'wa_settings': waSettings}), waSettings);
    expect(repository.extractWaSettings({}), isNull);
  });

  test('WhatsApp repository preserves wrapped ApiException', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter(
      (options) async => jsonResponse({'message': 'gateway down'}, statusCode: 502),
    );
    await expectLater(
      WhatsAppRepository(apiClient).requestPairingCode('+628'),
      throwsA(predicate((e) => e is ApiException && e.message == 'gateway down')),
    );
  });
}
