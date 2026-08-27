import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/update/update_models.dart';
import 'package:laundry/core/update/version.dart';
import 'package:laundry/core/update/update_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late UpdateService service;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: '/download'));
  });

  setUp(() {
    dio = _MockDio();
    service = UpdateService(dio);
  });

  AppVersionInfo info({
    String latest = '1.3.0',
    String min = '1.2.0',
    bool force = false,
  }) =>
      AppVersionInfo(
        latestVersion: Version.parse(latest),
        minVersion: Version.parse(min),
        apkUrl: 'https://example.com/app.apk',
        forceUpdate: force,
        changelog: 'Fixes',
      );

  test('parses version payload with defaults', () {
    final parsed = AppVersionInfo.fromJson({
      'latest_version': '2.0.0',
      'apk_url': '/app.apk',
    });
    expect(parsed.minVersion, Version.parse('0.0.0'));
    expect(parsed.forceUpdate, isFalse);
    expect(parsed.changelog, '');
  });

  test('classifies current, optional, and mandatory updates', () async {
    Future<UpdateCheckResult> check(String local) async {
      when(() => dio.get<dynamic>('/app/version')).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/app/version'),
          data: {'data': info().toJsonForTest()},
        ),
      );
      return service.checkForUpdate(PackageInfo(versionName: local, versionCode: 1));
    }

    expect((await check('1.4.0')).requirement, UpdateRequirement.none);
    expect((await check('1.2.5')).requirement, UpdateRequirement.optional);
  });

  test('force flag wins over current version and malformed payload skips', () async {
    final options = RequestOptions(path: '/app/version');
    when(() => dio.get<dynamic>('/app/version')).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: options,
        data: {'data': info(latest: '9.0.0', force: true).toJsonForTest()},
      ),
    );
    var result = await service.checkForUpdate(const PackageInfo(versionName: '9.0.0', versionCode: 9));
    expect(result.requirement, UpdateRequirement.mandatory);

    when(() => dio.get<dynamic>('/app/version')).thenAnswer(
      (_) async => Response<String>(requestOptions: options, data: 'not-json'),
    );
    result = await service.checkForUpdate(const PackageInfo(versionName: '9.0.0', versionCode: 9));
    expect(result.requirement, UpdateRequirement.none);
    expect(result.info, isNull);
  });
}

extension on AppVersionInfo {
  Map<String, dynamic> toJsonForTest() => {
        'latest_version': latestVersion.toString(),
        'min_version': minVersion.toString(),
        'apk_url': apkUrl,
        'force_update': forceUpdate,
        'changelog': changelog,
      };
}
