import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String kApiBaseUrl = 'http://18.216.165.127:5000/medicare/api';
const _kTokenKey = 'medicare_jwt';

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic> extra;

  ApiException(this.message,
      {this.code, this.statusCode, this.extra = const {}});

  @override
  String toString() => 'ApiException($code): $message';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: 'application/json',
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _kTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(_translateError(error));
        },
      ),
    );

  static DioException _translateError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['error'] as String? ?? 'Ocurrió un error inesperado';
      final code = data['code'] as String?;
      final extra = Map<String, dynamic>.from(data)
        ..remove('error')
        ..remove('code');
      return error.copyWith(
        error: ApiException(
          message,
          code: code,
          statusCode: error.response?.statusCode,
          extra: extra,
        ),
      );
    }

    return error.copyWith(
      error: ApiException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
        code: 'SIN_CONEXION',
      ),
    );
  }

  Future<void> guardarToken(String token) =>
      _storage.write(key: _kTokenKey, value: token);

  Future<String?> leerToken() => _storage.read(key: _kTokenKey);

  Future<void> borrarToken() => _storage.delete(key: _kTokenKey);
}
