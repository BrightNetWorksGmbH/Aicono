import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/features/settings/domain/entities/profile_update_request.dart';
import 'package:frontend_aicono/features/settings/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase {
  final ProfileRepository repository;

  UpdateProfileUseCase(this.repository);

  Future<Either<Failure, User>> call(ProfileUpdateRequest request) =>
      repository.updateProfile(request);
}
