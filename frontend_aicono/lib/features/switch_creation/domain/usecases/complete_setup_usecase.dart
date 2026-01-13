import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/complete_setup_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class CompleteSetupUseCase {
  final CompleteSetupRepository repository;

  CompleteSetupUseCase({required this.repository});

  Future<Either<Failure, CompleteSetupResponse>> call(
    String switchId,
    CompleteSetupRequest request,
  ) async {
    return await repository.completeSetup(switchId, request);
  }
}
