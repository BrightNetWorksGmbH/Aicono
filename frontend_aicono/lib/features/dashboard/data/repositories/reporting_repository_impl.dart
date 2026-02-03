import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/data/datasources/reporting_remote_datasource.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/trigger_report_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/reporting_repository.dart';

class ReportingRepositoryImpl implements ReportingRepository {
  final ReportingRemoteDataSource remoteDataSource;

  ReportingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, TriggerReportResponse>> triggerReportGeneration(
    String interval,
  ) async {
    return remoteDataSource.triggerReportGeneration(interval);
  }
}
