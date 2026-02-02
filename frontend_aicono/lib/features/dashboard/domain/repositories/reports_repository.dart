import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_site_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_building_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';

abstract class ReportsRepository {
  Future<Either<Failure, ReportSitesResponse>> getReportSites({
    String? bryteswitchId,
  });
  Future<Either<Failure, ReportBuildingsResponse>> getReportBuildings(
    String siteId,
  );
  Future<Either<Failure, BuildingReportsResponse>> getBuildingReports(
    String buildingId,
  );
  Future<Either<Failure, ReportDetailResponse>> getReportDetail(
    String reportId,
  );

  /// Fetches report view by token (public link, no auth required).
  Future<Either<Failure, ReportDetailResponse>> getReportViewByToken(
    String token,
  );
}
