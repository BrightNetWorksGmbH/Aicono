import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_floor_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardFloorDetailsUseCase {
  final DashboardRepository repository;

  GetDashboardFloorDetailsUseCase({required this.repository});

  Future<Either<Failure, DashboardFloorDetailsResponse>> call(
    String floorId, {
    DashboardDetailsFilter? filter,
  }) async {
    return repository.getFloorDetails(floorId, filter: filter);
  }
}
