import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reports_repository.dart';

class GetBuildingReportsUseCase {
  final ReportsRepository repository;

  GetBuildingReportsUseCase({required this.repository});

  Future<Either<Failure, BuildingReportsResponse>> call(
    String buildingId,
  ) async {
    return repository.getBuildingReports(buildingId);
  }
}
