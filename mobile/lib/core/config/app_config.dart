/// Application environment configuration.
///
/// Backend API endpoint (default: local Docker).
/// Override with --dart-define=API_BASE_URL=https://api.example.com
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8006/api/v1',
  );

  static const String appName = 'Laundry';

  static const Duration httpTimeout = Duration(seconds: 30);
}
