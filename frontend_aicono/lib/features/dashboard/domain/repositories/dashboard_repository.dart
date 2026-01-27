import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_sites_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_building_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_floor_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_room_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';

abstract class DashboardRepository {
  Future<Either<Failure, DashboardSitesResponse>> getSites();

  Future<Either<Failure, DashboardSiteDetailsResponse>> getSiteDetails(
    String siteId, {
    DashboardDetailsFilter? filter,
  });

  Future<Either<Failure, DashboardBuildingDetailsResponse>> getBuildingDetails(
    String buildingId, {
    DashboardDetailsFilter? filter,
  });

  Future<Either<Failure, DashboardFloorDetailsResponse>> getFloorDetails(
    String floorId, {
    DashboardDetailsFilter? filter,
  });

  Future<Either<Failure, DashboardRoomDetailsResponse>> getRoomDetails(
    String roomId, {
    DashboardDetailsFilter? filter,
  });
}

