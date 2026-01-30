import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_building_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reports_repository.dart';

class GetReportBuildingsUseCase {
  final ReportsRepository repository;

  GetReportBuildingsUseCase({required this.repository});

  Future<Either<Failure, ReportBuildingsResponse>> call(String siteId) async {
    return repository.getReportBuildings(siteId);
  }
}
