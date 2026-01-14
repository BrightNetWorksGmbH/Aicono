import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class GetBuildingsUseCase {
  final CompleteSetupRepository repository;

  GetBuildingsUseCase({required this.repository});

  Future<Either<Failure, GetBuildingsResponse>> call(String siteId) async {
    return await repository.getBuildings(siteId);
  }
}
