import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_building_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardBuildingDetailsUseCase {
  final DashboardRepository repository;

  GetDashboardBuildingDetailsUseCase({required this.repository});

  Future<Either<Failure, DashboardBuildingDetailsResponse>> call(
    String buildingId, {
    DashboardDetailsFilter? filter,
  }) async {
    return repository.getBuildingDetails(buildingId, filter: filter);
  }
}
