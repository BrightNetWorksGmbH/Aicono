import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_floors_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class GetFloorsUseCase {
  final CompleteSetupRepository repository;

  GetFloorsUseCase(this.repository);

  Future<Either<Failure, GetFloorsResponse>> call(String buildingId) async {
    return await repository.getFloors(buildingId);
  }
}

