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
        if (error.response?.statusCode != 401 || error.requestOptions.path.endsWith('/auth/refresh')) {
          handler.reject(error.copyWith(error: AppException.fromDio(error)));
          return;
        }

        final refreshToken = await _tokenStore.refreshToken;
        if (refreshToken == null) {
          handler.reject(error.copyWith(error: AppException.fromDio(error)));
          return;
        }

        try {
          final response = await dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
          await _tokenStore.saveTokens(
            accessToken: response.data['accessToken'],
            refreshToken: response.data['refreshToken'],
          );
          final retry = await dio.fetch(error.requestOptions);
          handler.resolve(retry);
        } catch (_) {
          await _tokenStore.clear();
          handler.reject(error.copyWith(error: AppException.fromDio(error)));
        }
      },
    ));
  }

  final TokenStore _tokenStore;
  late final Dio dio;
}
