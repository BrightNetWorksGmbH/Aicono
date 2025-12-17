import 'package:equatable/equatable.dart';

abstract class AppException extends Equatable implements Exception {
  final String message;
  final int? code;

  const AppException(this.message, [this.code]);

  @override
  List<Object?> get props => [message, code];
}

class ServerException extends AppException {
  const ServerException(super.message, [super.code]);
}

class CacheException extends AppException {
  const CacheException(super.message);
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class PermissionException extends AppException {
  const PermissionException(super.message);
}
