import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/settings/data/datasources/change_password_remote_datasource.dart';
import 'package:frontend_aicono/features/settings/domain/repositories/change_password_repository.dart';

class ChangePasswordRepositoryImpl implements ChangePasswordRepository {
  final ChangePasswordRemoteDataSource remoteDataSource;

  ChangePasswordRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) =>
      remoteDataSource.changePassword(
        currentPassword,
        newPassword,
        confirmPassword,
      );
}
