class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://newcarpool-g3cscbgwaye5e2fy.centralindia-01.azurewebsites.net',
  );

  static const openRouteServiceApiKey = String.fromEnvironment(
    'OPEN_ROUTE_SERVICE_API_KEY',
    defaultValue: '',
  );

  static const tomTomApiKey = String.fromEnvironment(
    'TOMTOM_API_KEY',
    defaultValue: '',
  );

  static const nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
}
