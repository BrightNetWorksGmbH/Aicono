import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/loxone_connection_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class ConnectLoxoneUseCase {
  final CompleteSetupRepository repository;

  ConnectLoxoneUseCase({required this.repository});

  Future<Either<Failure, LoxoneConnectionResponse>> call(
    String buildingId,
    LoxoneConnectionRequest request,
  ) async {
    return await repository.connectLoxone(buildingId, request);
  }
}

