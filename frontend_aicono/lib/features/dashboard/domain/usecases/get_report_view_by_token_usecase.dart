import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reports_repository.dart';

/// Use case for fetching report view by token (public report link).
class GetReportViewByTokenUseCase {
  final ReportsRepository repository;

  GetReportViewByTokenUseCase({required this.repository});

  Future<Either<Failure, ReportDetailResponse>> call(String token) async {
    return repository.getReportViewByToken(token);
  }
}
