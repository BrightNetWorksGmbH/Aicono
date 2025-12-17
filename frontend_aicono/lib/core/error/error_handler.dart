import 'package:flutter/foundation.dart';
import 'exceptions.dart';
import 'failure.dart';

/// Global error handler for the application
class ErrorHandler {
  /// Handles Flutter framework errors
  static void handleFlutterError(FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    // In production, you might want to send this to a crash reporting service
  }

  /// Converts exceptions to failures for clean architecture
  static Failure mapExceptionToFailure(Exception exception) {
    if (exception is AppException) {
      return _mapAppExceptionToFailure(exception);
    }
    return const ServerFailure('An unexpected error occurred');
  }

  static Failure _mapAppExceptionToFailure(AppException exception) {
    if (exception is ServerException) {
      return ServerFailure(exception.message, exception.code);
    } else if (exception is CacheException) {
      return CacheFailure(exception.message);
    } else if (exception is NetworkException) {
      return NetworkFailure(exception.message);
    } else if (exception is ValidationException) {
      return ValidationFailure(exception.message);
    } else if (exception is PermissionException) {
      return PermissionFailure(exception.message);
    } else {
      return const ServerFailure('An unknown error occurred');
    }
  }

  /// Registers global error handlers
  static void registerErrorHandlers() {
    // Handle Flutter framework errors
    FlutterError.onError = handleFlutterError;

    // Handle Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      // In production, you might want to send this to a crash reporting service
      return true;
    };
  }
}
