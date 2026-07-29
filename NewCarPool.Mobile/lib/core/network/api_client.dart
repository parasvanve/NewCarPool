import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient(this._tokenStore) {
    dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.apiBaseUrl}/api',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStore.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // 1. Agar error 401 nahi hai, YA fir refresh token ki request khud fail hui hai
        if (error.response?.statusCode != 401 ||
            error.requestOptions.path.endsWith('/auth/refresh')) {
          dynamic parsedException;
          try {
            parsedException = AppException.fromDio(error);
          } catch (e) {
            parsedException = 'Request failed: ${error.message}';
          }
          // FIX: copyWith ka sahi use, jisme Object parameter pass ho raha hai bina setter error ke
          handler.reject(error.copyWith(error: parsedException));
          return;
        }

        // 2. Refresh token flow for 401 Unauthorized errors
        final refreshToken = await _tokenStore.refreshToken;
        if (refreshToken == null) {
          dynamic parsedException;
          try {
            parsedException = AppException.fromDio(error);
          } catch (_) {
            parsedException = 'Session expired';
          }
          handler.reject(error.copyWith(error: parsedException));
          return;
        }

        try {
          // Token refresh karne ki request
          final response = await dio
              .post('/auth/refresh', data: {'refreshToken': refreshToken});

          await _tokenStore.saveTokens(
            accessToken: response.data['accessToken'],
            refreshToken: response.data['refreshToken'],
          );

          final newToken = response.data['accessToken'];

          // Clone options for retry with updated authentication header
          final requestOptions = error.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newToken';

          // Request retry karein
          final retry = await dio.fetch(requestOptions);
          handler.resolve(retry);
        } catch (_) {
          await _tokenStore.clear();

          dynamic parsedException;
          try {
            parsedException = AppException.fromDio(error);
          } catch (_) {
            parsedException = 'Session expired. Please sign in again.';
          }
          handler.reject(error.copyWith(error: parsedException));
        }
      },
    ));
  }

  final TokenStore _tokenStore;
  late final Dio dio;
}
