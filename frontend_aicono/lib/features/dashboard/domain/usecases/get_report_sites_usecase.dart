import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_site_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reports_repository.dart';

class GetReportSitesUseCase {
  final ReportsRepository repository;

  GetReportSitesUseCase({required this.repository});

  Future<Either<Failure, ReportSitesResponse>> call() async {
    return repository.getReportSites();
  }
}
