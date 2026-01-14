import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/complete_setup_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_buildings_entity.dart';

abstract class CompleteSetupRepository {
  Future<Either<Failure, CompleteSetupResponse>> completeSetup(
    String switchId,
    CompleteSetupRequest request,
  );

  Future<Either<Failure, CreateSiteResponse>> createSite(
    String switchId,
    CreateSiteRequest request,
  );

  Future<Either<Failure, GetSiteResponse>> getSite(String siteId);

  Future<Either<Failure, CreateBuildingsResponse>> createBuildings(
    String siteId,
    CreateBuildingsRequest request,
  );
}
