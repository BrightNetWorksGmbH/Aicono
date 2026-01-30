import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class UpdateSiteUseCase {
  final CompleteSetupRepository repository;

  UpdateSiteUseCase({required this.repository});

  Future<Either<Failure, CreateSiteResponse>> call(
    String siteId,
    CreateSiteRequest request,
  ) async {
    return await repository.updateSite(siteId, request);
  }
}

