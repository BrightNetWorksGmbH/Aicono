import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_token_info_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reports_repository.dart';

/// Use case for fetching report token info (recipient, building, reporting).
class GetReportTokenInfoUseCase {
  final ReportsRepository repository;

  GetReportTokenInfoUseCase({required this.repository});

  Future<Either<Failure, ReportTokenInfoResponse>> call(String token) async {
    return repository.getReportTokenInfo(token);
  }
}
