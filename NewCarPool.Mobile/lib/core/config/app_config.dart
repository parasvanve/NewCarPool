class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7030',
  );

  static const openRouteServiceApiKey = String.fromEnvironment(
    'OPEN_ROUTE_SERVICE_API_KEY',
    defaultValue: '',
  );

  static const nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
}
