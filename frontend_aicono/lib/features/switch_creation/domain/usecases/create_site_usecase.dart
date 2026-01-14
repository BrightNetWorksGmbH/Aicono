import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class CreateSiteUseCase {
  final CompleteSetupRepository repository;

  CreateSiteUseCase({required this.repository});

  Future<Either<Failure, CreateSiteResponse>> call(
    String switchId,
    CreateSiteRequest request,
  ) async {
    return await repository.createSite(switchId, request);
  }
}
