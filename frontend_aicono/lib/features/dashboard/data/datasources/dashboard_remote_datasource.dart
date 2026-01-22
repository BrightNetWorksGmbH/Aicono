import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_sites_entity.dart';

abstract class DashboardRemoteDataSource {
  Future<Either<Failure, DashboardSitesResponse>> getSites();

  Future<Either<Failure, DashboardSiteDetailsResponse>> getSiteDetails(
    String siteId,
  );
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final DioClient dioClient;

  DashboardRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, DashboardSitesResponse>> getSites() async {
    try {
      if (kDebugMode) {
        print('📤 Dashboard getSites request');
      }

      final response = await dioClient.get('/api/v1/dashboard/sites');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == true) {
            return Right(DashboardSitesResponse.fromJson(data));
          }
          return Left(
            ServerFailure(
              (data['message'] ?? 'Failed to load sites.').toString(),
            ),
          );
        }
        // If backend returns raw list (unexpected), wrap it
        if (data is List) {
          return Right(
            DashboardSitesResponse.fromJson({
              'success': true,
              'data': data,
              'count': data.length,
            }),
          );
        }
        return const Left(ServerFailure('Unexpected response format.'));
      }

      return Left(
        ServerFailure('Failed to load sites (HTTP ${response.statusCode})'),
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
        print('❌ Dashboard getSites unexpected error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, DashboardSiteDetailsResponse>> getSiteDetails(
    String siteId,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Dashboard getSiteDetails request: siteId=$siteId');
      }

      final response = await dioClient.get('/api/v1/dashboard/sites/$siteId');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == true) {
            return Right(DashboardSiteDetailsResponse.fromJson(data));
          }
          return Left(
            ServerFailure(
              (data['message'] ?? 'Failed to load site details.').toString(),
            ),
          );
        }
        // If backend returns raw object (unexpected), wrap it
        if (data is Map) {
          return Right(
            DashboardSiteDetailsResponse.fromJson(
              data.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
        return const Left(ServerFailure('Unexpected response format.'));
      }

      return Left(
        ServerFailure(
          'Failed to load site details (HTTP ${response.statusCode})',
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Site not found'));
      }
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
        print('❌ Dashboard getSiteDetails unexpected error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}

