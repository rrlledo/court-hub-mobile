import 'package:dio/dio.dart';

class Api {
  Api({Dio? client})
      : dio = client ??
            Dio(BaseOptions(
              baseUrl: const String.fromEnvironment('API_BASE_URL',
                  defaultValue: 'http://10.0.2.2:8000/api/v1'),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  final Dio dio;
  void Function()? onUnauthorized;

  void setToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    try {
      final response = await dio.request<dynamic>(path,
          data: data, queryParameters: query, options: Options(method: method));
      return response.data;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && path != '/auth/login') {
        onUnauthorized?.call();
      }
      rethrow;
    }
  }
}

String errorMessage(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['message'] is String) {
      return body['message'] as String;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'The request timed out. Please try again.';
    }
    return 'Unable to reach Court Hub. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}

class ApiPage {
  ApiPage(this.items, this.hasMore);
  final List<Map<String, dynamic>> items;
  final bool hasMore;

  factory ApiPage.parse(dynamic body) {
    dynamic page = body;
    // Laravel resource collections and wrapped paginator responses.
    if (page is Map && page['data'] is Map) page = page['data'];
    final dynamic rows = page is List ? page : page['data'];
    final meta = page is Map ? (page['meta'] ?? page) : null;
    return ApiPage(
      (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      meta is Map && meta['current_page'] is num && meta['last_page'] is num
          ? (meta['current_page'] as num) < (meta['last_page'] as num)
          : page is Map && page['next_page_url'] != null,
    );
  }
}
