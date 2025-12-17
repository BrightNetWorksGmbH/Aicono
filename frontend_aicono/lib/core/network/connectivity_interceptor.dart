import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ConnectivityInterceptor extends Interceptor {
  final Connectivity _connectivity = Connectivity();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Check connectivity before making request
    final connectivityResult = await _connectivity.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      if (kDebugMode) {
        print('❌ No internet connection available');
      }

      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'No internet connection available',
      );

      handler.reject(error);
      return;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle connectivity-related errors
    if (err.type == DioExceptionType.connectionError) {
      if (kDebugMode) {
        print('❌ Connection error: ${err.message}');
      }
    }

    handler.next(err);
  }
}
