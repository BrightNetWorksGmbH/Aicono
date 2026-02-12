import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/features/settings/data/datasources/profile_remote_datasource.dart';
import 'package:frontend_aicono/features/settings/domain/entities/profile_update_request.dart';
import 'package:frontend_aicono/features/settings/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, User>> getProfile() =>
      remoteDataSource.getProfile();

  @override
  Future<Either<Failure, User>> updateProfile(
    ProfileUpdateRequest request,
  ) =>
      remoteDataSource.updateProfile(request);
}
