import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_site_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_building_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_token_info_entity.dart';

abstract class ReportsRemoteDataSource {
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

  /// Fetches report token info (recipient, building, reporting) by token.
  Future<Either<Failure, ReportTokenInfoResponse>> getReportTokenInfo(
    String token,
  );
}

class ReportsRemoteDataSourceImpl implements ReportsRemoteDataSource {
  final DioClient dioClient;

  ReportsRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, ReportSitesResponse>> getReportSites({
    String? bryteswitchId,
  }) async {
    try {
      if (kDebugMode) {
        print('📤 Reports getReportSites request bryteswitchId=$bryteswitchId');
      }
      final queryParams = bryteswitchId != null && bryteswitchId.isNotEmpty
          ? <String, dynamic>{'bryteswitch_id': bryteswitchId}
          : null;
      final response = await dioClient.get(
        '/api/v1/dashboard/reports/sites',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return Right(ReportSitesResponse.fromJson(data));
        }
        return Left(
          ServerFailure(
            (data is Map ? (data as Map)['message'] : null)?.toString() ??
                'Failed to load report sites.',
          ),
        );
      }
      return Left(
        ServerFailure(
          'Failed to load report sites (HTTP ${response.statusCode})',
        ),
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
        print('❌ Reports getReportSites error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, ReportBuildingsResponse>> getReportBuildings(
    String siteId,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Reports getReportBuildings siteId=$siteId');
      }
      final response = await dioClient.get(
        '/api/v1/dashboard/reports/sites/$siteId/buildings',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return Right(ReportBuildingsResponse.fromJson(data));
        }
        return Left(
          ServerFailure(
            (data is Map ? (data as Map)['message'] : null)?.toString() ??
                'Failed to load buildings.',
          ),
        );
      }
      return Left(
        ServerFailure('Failed to load buildings (HTTP ${response.statusCode})'),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Reports getReportBuildings error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, BuildingReportsResponse>> getBuildingReports(
    String buildingId,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Reports getBuildingReports buildingId=$buildingId');
      }
      final response = await dioClient.get(
        '/api/v1/dashboard/reports/buildings/$buildingId/reports',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return Right(BuildingReportsResponse.fromJson(data));
        }
        return Left(
          ServerFailure(
            (data is Map ? (data as Map)['message'] : null)?.toString() ??
                'Failed to load reports.',
          ),
        );
      }
      return Left(
        ServerFailure('Failed to load reports (HTTP ${response.statusCode})'),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Reports getBuildingReports error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, ReportDetailResponse>> getReportDetail(
    String reportId,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Reports getReportDetail reportId=$reportId');
      }
      final response = await dioClient.get(
        '/api/v1/dashboard/reports/view/$reportId',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return Right(ReportDetailResponse.fromJson(data));
        }
        return Left(
          ServerFailure(
            (data is Map ? (data as Map)['message'] : null)?.toString() ??
                'Failed to load report detail.',
          ),
        );
      }
      return Left(
        ServerFailure(
          'Failed to load report detail (HTTP ${response.statusCode})',
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Reports getReportDetail error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, ReportDetailResponse>> getReportViewByToken(
    String token,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Reports getReportViewByToken (token-based)');
      }
      final response = await dioClient.get(
        '/api/v1/reports/view',
        queryParameters: {'token': token},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return Right(ReportDetailResponse.fromJson(data));
        }
        return Left(
          ServerFailure(
            (data is Map ? (data as Map)['message'] : null)?.toString() ??
                'Failed to load report.',
          ),
        );
      }
      return Left(
        ServerFailure('Failed to load report (HTTP ${response.statusCode})'),
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
        print('❌ Reports getReportViewByToken error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, ReportTokenInfoResponse>> getReportTokenInfo(
    String token,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Reports getReportTokenInfo (token-based)');
      }
      final response = await dioClient.get(
        '/api/v1/reporting/token/info',
        queryParameters: {'token': token},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return Right(ReportTokenInfoResponse.fromJson(data));
        }
        return Left(
          ServerFailure(
            (data is Map ? (data as Map)['message'] : null)?.toString() ??
                'Failed to load report info.',
          ),
        );
      }
      return Left(
        ServerFailure(
          'Failed to load report info (HTTP ${response.statusCode})',
        ),
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
        print('❌ Reports getReportTokenInfo error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
