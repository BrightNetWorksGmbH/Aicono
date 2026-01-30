import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/data/datasources/reports_remote_datasource.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_site_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_building_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  final ReportsRemoteDataSource remoteDataSource;

  ReportsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, ReportSitesResponse>> getReportSites() async {
    return remoteDataSource.getReportSites();
  }

  @override
  Future<Either<Failure, ReportBuildingsResponse>> getReportBuildings(
    String siteId,
  ) async {
    return remoteDataSource.getReportBuildings(siteId);
  }

  @override
  Future<Either<Failure, BuildingReportsResponse>> getBuildingReports(
    String buildingId,
  ) async {
    return remoteDataSource.getBuildingReports(buildingId);
  }

  @override
  Future<Either<Failure, ReportDetailResponse>> getReportDetail(
    String reportId,
  ) async {
    return remoteDataSource.getReportDetail(reportId);
  }
}
