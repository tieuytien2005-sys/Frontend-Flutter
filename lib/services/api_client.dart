import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int statusCode;

  ApiResponse({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    required this.statusCode,
  });
}

class ApiClient {
  static Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static String _extractErrorMessage(http.Response response) {
    if (response.statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn (401). Vui lòng đăng xuất và đăng nhập lại.';
    }
    if (response.statusCode == 403) {
      return 'Tài khoản không có quyền Admin để truy cập dữ liệu này (403 Forbidden).';
    }
    if (response.statusCode == 404) {
      return 'Không tìm thấy dữ liệu hoặc máy chủ (404 Not Found).';
    }
    if (response.statusCode >= 500) {
      return 'Máy chủ backend gặp sự cố nội bộ (${response.statusCode}).';
    }

    try {
      final responseBody = utf8.decode(response.bodyBytes);
      if (responseBody.isNotEmpty) {
        final body = jsonDecode(responseBody);
        if (body is Map<String, dynamic>) {
          if (body.containsKey('message')) return body['message'].toString();
          if (body.containsKey('title')) {
            if (body.containsKey('errors') && body['errors'] is Map) {
              final errorsMap = body['errors'] as Map;
              final firstKey = errorsMap.keys.firstOrNull;
              if (firstKey != null && errorsMap[firstKey] is List && (errorsMap[firstKey] as List).isNotEmpty) {
                return errorsMap[firstKey][0].toString();
              }
            }
            return body['title'].toString();
          }
        }
        if (responseBody.length < 200) {
          return responseBody;
        }
      }
    } catch (_) {}

    return 'Lỗi máy chủ (${response.statusCode})';
  }

  static Future<ApiResponse<dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      final responseBody = utf8.decode(response.bodyBytes);

      if (isSuccess) {
        dynamic data;
        if (responseBody.isNotEmpty) {
          try {
            data = jsonDecode(responseBody);
          } catch (_) {
            data = responseBody;
          }
        }
        return ApiResponse(
          isSuccess: true,
          data: data,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          isSuccess: false,
          errorMessage: _extractErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        errorMessage: 'Lỗi kết nối mạng: $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse<dynamic>> get(
    String url, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      final responseBody = utf8.decode(response.bodyBytes);

      if (isSuccess) {
        dynamic data;
        if (responseBody.isNotEmpty) {
          try {
            data = jsonDecode(responseBody);
          } catch (_) {
            data = responseBody;
          }
        }
        return ApiResponse(
          isSuccess: true,
          data: data,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          isSuccess: false,
          errorMessage: _extractErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        errorMessage: 'Lỗi kết nối mạng: $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse<dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      final responseBody = utf8.decode(response.bodyBytes);

      if (isSuccess) {
        dynamic data;
        if (responseBody.isNotEmpty) {
          try {
            data = jsonDecode(responseBody);
          } catch (_) {
            data = responseBody;
          }
        }
        return ApiResponse(
          isSuccess: true,
          data: data,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          isSuccess: false,
          errorMessage: _extractErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        errorMessage: 'Lỗi kết nối mạng: $e',
        statusCode: 0,
      );
    }
  }

  static Future<ApiResponse<dynamic>> delete(
    String url, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      final responseBody = utf8.decode(response.bodyBytes);

      if (isSuccess) {
        return ApiResponse(
          isSuccess: true,
          data: responseBody,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          isSuccess: false,
          errorMessage: _extractErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        errorMessage: 'Lỗi kết nối mạng: $e',
        statusCode: 0,
      );
    }
  }
}