import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/trigger_report_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reporting_repository.dart';

/// Use case for triggering manual report generation.
class TriggerReportUseCase {
  final ReportingRepository repository;

  TriggerReportUseCase({required this.repository});

  Future<Either<Failure, TriggerReportResponse>> call(String interval) async {
    return repository.triggerReportGeneration(interval);
  }
}
