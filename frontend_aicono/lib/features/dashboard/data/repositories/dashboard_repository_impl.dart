import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_sites_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_building_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_floor_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_room_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource remoteDataSource;

  DashboardRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, DashboardSitesResponse>> getSites() async {
    return remoteDataSource.getSites();
  }

  @override
  Future<Either<Failure, DashboardSiteDetailsResponse>> getSiteDetails(
    String siteId, {
    DashboardDetailsFilter? filter,
  }) async {
    return remoteDataSource.getSiteDetails(siteId, filter: filter);
  }

  @override
  Future<Either<Failure, DashboardBuildingDetailsResponse>> getBuildingDetails(
    String buildingId, {
    DashboardDetailsFilter? filter,
  }) async {
    return remoteDataSource.getBuildingDetails(buildingId, filter: filter);
  }

  @override
  Future<Either<Failure, DashboardFloorDetailsResponse>> getFloorDetails(
    String floorId, {
    DashboardDetailsFilter? filter,
  }) async {
    return remoteDataSource.getFloorDetails(floorId, filter: filter);
  }

  @override
  Future<Either<Failure, DashboardRoomDetailsResponse>> getRoomDetails(
    String roomId, {
    DashboardDetailsFilter? filter,
  }) async {
    return remoteDataSource.getRoomDetails(roomId, filter: filter);
  }
}
