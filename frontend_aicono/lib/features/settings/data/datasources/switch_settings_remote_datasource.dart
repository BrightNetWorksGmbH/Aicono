import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/settings/data/models/switch_details_model.dart';
import 'package:frontend_aicono/features/settings/domain/entities/switch_details_entity.dart';
import 'package:frontend_aicono/features/settings/domain/entities/update_switch_request.dart';

/// Remote data source for switch settings API.
abstract class SwitchSettingsRemoteDataSource {
  Future<Either<Failure, SwitchDetailsEntity>> getSwitchById(String switchId);
  Future<Either<Failure, SwitchDetailsEntity>> updateSwitch(
    String switchId,
    UpdateSwitchRequest request,
  );
}

class SwitchSettingsRemoteDataSourceImpl
    implements SwitchSettingsRemoteDataSource {
  final DioClient dioClient;

  SwitchSettingsRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, SwitchDetailsEntity>> getSwitchById(
    String switchId,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Get Switch Request: switchId=$switchId');
      }

      final response = await dioClient.get('/api/v1/bryteswitch/$switchId');

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          final model = SwitchDetailsModel.fromJson(
            responseData is Map<String, dynamic>
                ? responseData
                : {'success': true, 'data': responseData},
          );
          return Right(model.toEntity());
        }
        return Left(
          ServerFailure(
            responseData['message'] ?? 'Failed to fetch switch details.',
          ),
        );
      }
      return Left(
        ServerFailure(
          'Failed to fetch switch with status ${response.statusCode}',
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Switch not found'));
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
        print('❌ Get switch error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, SwitchDetailsEntity>> updateSwitch(
    String switchId,
    UpdateSwitchRequest request,
  ) async {
    try {
      final requestData = request.toJson();
      if (kDebugMode) {
        print('📤 Update Switch Request: switchId=$switchId, data=$requestData');
      }

      final response = await dioClient.put(
        '/api/v1/bryteswitch/$switchId',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          final model = SwitchDetailsModel.fromJson(
            responseData is Map<String, dynamic>
                ? responseData
                : {'success': true, 'data': responseData},
          );
          return Right(model.toEntity());
        }
        return Left(
          ServerFailure(
            responseData['message'] ?? 'Failed to update switch.',
          ),
        );
      }
      return Left(
        ServerFailure(
          'Failed to update switch with status ${response.statusCode}',
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Switch not found'));
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
        print('❌ Update switch error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
