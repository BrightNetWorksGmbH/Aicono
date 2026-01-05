import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/storage/secure_storage.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('🚀 REQUEST[${options.method}] => PATH: ${options.path}');
      print('Headers: ${options.headers}');
      if (options.data != null) {
        print('Data: ${options.data}');
      }
      if (options.queryParameters.isNotEmpty) {
        print('Query Parameters: ${options.queryParameters}');
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print(
        '✅ RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
      );
      // Avoid printing binary or very large payloads (like zip files)
      final contentType = response.headers.value('content-type') ?? '';
      final isBinary =
          contentType.contains('application/zip') ||
          contentType.contains('application/octet-stream') ||
          response.data is List<int>;
      if (!isBinary) {
        print('Data: ${response.data}');
      } else {
        print('Data: <binary ${contentType.isEmpty ? 'bytes' : contentType}>');
      }
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print(
        '❌ ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}',
      );
      print('Message: ${err.message}');
      print('Response: ${err.response?.data}');
    }
    super.onError(err, handler);
  }
}

class AuthInterceptor extends Interceptor {
  final Dio dio;
  bool _isRefreshing = false;
  final List<RequestOptions> _pendingRequests = [];

  AuthInterceptor({required this.dio});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      print('🔐 AuthInterceptor: Checking path: ${options.path}');
      print('🔐 Should skip auth: ${_shouldSkipAuth(options.path)}');
    }

    // Skip auth for certain endpoints
    if (_shouldSkipAuth(options.path)) {
      if (kDebugMode) {
        print('🔐 Skipping auth for: ${options.path}');
      }
      handler.next(options);
      return;
    }

    // Get access token from secure storage
    final accessToken = await SecureStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
      if (kDebugMode) {
        print('🔐 Added auth token for: ${options.path}');
      }
    } else {
      if (kDebugMode) {
        print('🔐 No auth token available for: ${options.path}');
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        !_shouldSkipAuth(err.requestOptions.path)) {
      if (_isRefreshing) {
        // Add request to pending queue
        _pendingRequests.add(err.requestOptions);
        return;
      }

      _isRefreshing = true;

      try {
        // Get refresh token from secure storage
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          throw Exception('No refresh token available');
        }

        // Refresh token logic
        final newTokens = await _refreshToken(refreshToken);
        await SecureStorage.saveTokens(
          newTokens['accessToken']!,
          newTokens['refreshToken'] ??
              newTokens['accessToken']!, // Use accessToken as refreshToken if not provided
        );

        // Update original request with new token
        final request = err.requestOptions;
        request.headers['Authorization'] = 'Bearer ${newTokens['accessToken']}';

        // Retry the original request
        final response = await dio.fetch(request);

        // Process pending requests
        await _processPendingRequests(newTokens['accessToken']!);

        handler.resolve(response);
      } catch (e) {
        if (kDebugMode) {
          print('Token refresh failed: $e');
        }
        // Clear tokens on refresh failure
        await SecureStorage.clearTokens();
        handler.reject(err);
      } finally {
        _isRefreshing = false;
        _pendingRequests.clear();
      }
    } else {
      handler.next(err);
    }
  }

  bool _shouldSkipAuth(String path) {
    final skipPaths = [
      '/auth/login',
      '/api/v1/auth/login',
      '/auth/register',
      '/api/v1/auth/register',
      '/auth/refresh',
      '/auth/forgot-password',
      '/api/v1/auth/forgot-password',
      '/auth/reset-password',
      '/api/v1/auth/reset-password',
      '/invitation/validate',
    ];

    // Skip simple substring matches first
    if (skipPaths.any((skipPath) => path.contains(skipPath))) {
      return true;
    }

    // Public invitation token endpoint: /api/v1/invitations/token/{token}
    // Also support old format: /invitation/{token}
    final invitationTokenPattern = RegExp(r'^/api/v1/invitations/token/[^/]+$');
    if (invitationTokenPattern.hasMatch(path)) {
      return true;
    }

    final invitationTokenOnly = RegExp(r'^/invitation/[^/]+$');
    if (invitationTokenOnly.hasMatch(path)) {
      return true;
    }

    // Public user email check endpoint: /api/v1/auth/user/email/{email}
    final userEmailPattern = RegExp(r'^/api/v1/auth/user/email/[^/]+$');
    if (userEmailPattern.hasMatch(path)) {
      return true;
    }

    return false;
  }

  Future<void> _processPendingRequests(String newAccessToken) async {
    for (final request in _pendingRequests) {
      request.headers['Authorization'] = 'Bearer $newAccessToken';
      try {
        await dio.fetch(request);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to retry pending request: $e');
        }
      }
    }
  }

  Future<Map<String, String>> _refreshToken(String refreshToken) async {
    // Create a new Dio instance to avoid circular dependency
    final refreshDio = Dio();
    refreshDio.options = dio.options.copyWith(baseUrl: dio.options.baseUrl);

    final response = await refreshDio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    if (response.statusCode == 200) {
      return {
        'accessToken': response.data['accessToken'] ?? response.data['token'],
        'refreshToken': response.data['refreshToken'], // May be null
      };
    } else {
      throw Exception(
        'Token refresh failed with status: ${response.statusCode}',
      );
    }
  }
}
