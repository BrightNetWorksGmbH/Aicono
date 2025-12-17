import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/data/datasources/forgot_password_remote_datasource.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/forgot_password_repository.dart';

class ForgotPasswordRepositoryImpl implements ForgotPasswordRepository {
  final ForgotPasswordRemoteDataSource remoteDataSource;

  ForgotPasswordRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> sendResetLink(String email) async {
    return await remoteDataSource.sendResetLink(email);
  }
}
