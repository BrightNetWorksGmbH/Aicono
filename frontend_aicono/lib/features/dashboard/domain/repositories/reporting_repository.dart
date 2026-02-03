import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/trigger_report_entity.dart';

abstract class ReportingRepository {
  /// Triggers manual report generation for the given interval.
  Future<Either<Failure, TriggerReportResponse>> triggerReportGeneration(
    String interval,
  );
}
