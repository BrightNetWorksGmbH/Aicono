import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/complete_setup_entity.dart';

abstract class CompleteSetupRepository {
  Future<Either<Failure, CompleteSetupResponse>> completeSetup(
    String switchId,
    CompleteSetupRequest request,
  );
}
