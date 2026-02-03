import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/trigger_report_entity.dart';

/// Data source for reporting module (trigger, scheduler, etc.).
/// Requires authentication.
abstract class ReportingRemoteDataSource {
  /// Triggers manual report generation for the given interval.
  /// POST /api/v1/reporting/trigger/:interval
  Future<Either<Failure, TriggerReportResponse>> triggerReportGeneration(
    String interval,
  );
}

class ReportingRemoteDataSourceImpl implements ReportingRemoteDataSource {
  final DioClient dioClient;

  ReportingRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, TriggerReportResponse>> triggerReportGeneration(
    String interval,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Reporting triggerReportGeneration interval=$interval');
      }
      final response = await dioClient.post(
        '/api/v1/reporting/trigger/$interval',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return Right(TriggerReportResponse.fromJson(data));
        }
        return Left(
          ServerFailure(
            (data is Map ? (data as Map)['message'] : null)?.toString() ??
                'Failed to trigger report.',
          ),
        );
      }
      return Left(
        ServerFailure('Failed to trigger report (HTTP ${response.statusCode})'),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Reporting triggerReportGeneration error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
