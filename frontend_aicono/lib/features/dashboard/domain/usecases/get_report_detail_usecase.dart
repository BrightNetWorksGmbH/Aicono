import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reports_repository.dart';

class GetReportDetailUseCase {
  final ReportsRepository repository;

  GetReportDetailUseCase({required this.repository});

  Future<Either<Failure, ReportDetailResponse>> call(
    String reportId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return repository.getReportDetail(
      reportId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
