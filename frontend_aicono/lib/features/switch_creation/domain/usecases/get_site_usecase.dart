import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class GetSiteUseCase {
  final CompleteSetupRepository repository;

  GetSiteUseCase({required this.repository});

  Future<Either<Failure, GetSiteResponse>> call(String siteId) async {
    return await repository.getSite(siteId);
  }
}
