import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  factory AppException.fromDio(DioException exception) {
    final data = exception.response?.data;
    if (data is Map<String, dynamic>) {
      final rawErrors = data['errors'];
      return AppException(
        data['title']?.toString() ?? data['message']?.toString() ?? 'Something went wrong.',
        statusCode: exception.response?.statusCode,
        errors: rawErrors is Map
            ? rawErrors.map((key, value) => MapEntry(
                  key.toString(),
                  value is List ? value.map((item) => item.toString()).toList() : [value.toString()],
                ))
            : null,
      );
    }

    return AppException(
      exception.message ?? 'Network request failed.',
      statusCode: exception.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
