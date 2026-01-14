import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class CreateBuildingsUseCase {
  final CompleteSetupRepository repository;

  CreateBuildingsUseCase({required this.repository});

  Future<Either<Failure, CreateBuildingsResponse>> call(
    String siteId,
    CreateBuildingsRequest request,
  ) async {
    return await repository.createBuildings(siteId, request);
  }
}
