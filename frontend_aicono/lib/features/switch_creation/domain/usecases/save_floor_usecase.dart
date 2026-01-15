import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/save_floor_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class SaveFloorUseCase {
  final CompleteSetupRepository repository;

  SaveFloorUseCase({required this.repository});

  Future<Either<Failure, SaveFloorResponse>> call(
    String buildingId,
    SaveFloorRequest request,
  ) async {
    return await repository.saveFloor(buildingId, request);
  }
}

