import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/data/datasources/complete_setup_remote_data_source.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/complete_setup_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class CompleteSetupRepositoryImpl implements CompleteSetupRepository {
  final CompleteSetupRemoteDataSource remoteDataSource;

  CompleteSetupRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, CompleteSetupResponse>> completeSetup(
    String switchId,
    CompleteSetupRequest request,
  ) async {
    return await remoteDataSource.completeSetup(switchId, request);
  }

  @override
  Future<Either<Failure, CreateSiteResponse>> createSite(
    String switchId,
    CreateSiteRequest request,
  ) async {
    return await remoteDataSource.createSite(switchId, request);
  }

  @override
  Future<Either<Failure, GetSiteResponse>> getSite(String siteId) async {
    return await remoteDataSource.getSite(siteId);
  }

  @override
  Future<Either<Failure, CreateBuildingsResponse>> createBuildings(
    String siteId,
    CreateBuildingsRequest request,
  ) async {
    return await remoteDataSource.createBuildings(siteId, request);
  }

  @override
  Future<Either<Failure, GetBuildingsResponse>> getBuildings(String siteId) async {
    return await remoteDataSource.getBuildings(siteId);
  }
}
