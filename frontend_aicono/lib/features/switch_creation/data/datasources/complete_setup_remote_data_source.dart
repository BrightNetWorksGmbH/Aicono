import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/complete_setup_entity.dart';

abstract class CompleteSetupRemoteDataSource {
  Future<Either<Failure, CompleteSetupResponse>> completeSetup(
    String switchId,
    CompleteSetupRequest request,
  );
}

class CompleteSetupRemoteDataSourceImpl
    implements CompleteSetupRemoteDataSource {
  final DioClient dioClient;

  CompleteSetupRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, CompleteSetupResponse>> completeSetup(
    String switchId,
    CompleteSetupRequest request,
  ) async {
    try {
      final requestData = request.toJson();
      
      // Debug: Print the exact JSON being sent
      if (kDebugMode) {
        print('📤 Complete Setup Request Data:');
        print('Switch ID: $switchId');
        print('Request JSON: $requestData');
        // Print formatted JSON for easier debugging
        try {
          final jsonString = jsonEncode(requestData);
          print('Formatted JSON: $jsonString');
        } catch (e) {
          print('Error encoding JSON: $e');
        }
      }
      
      // Pass Map directly - Dio will serialize it automatically
      // This matches the pattern used in register_user_remote_datasource and login_repository_impl
      final response = await dioClient.post(
        '/api/v1/bryteswitch/$switchId/complete-setup',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        // Check for success flag
        if (responseData['success'] == true) {
          final completeSetupResponse = CompleteSetupResponse.fromJson(
            responseData,
          );
          return Right(completeSetupResponse);
        } else {
          return Left(
            ServerFailure(
              responseData['message'] ??
                  'Setup completion failed. Please try again.',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            'Setup completion failed with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Switch not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(
          ServerFailure('Request timed out. Please try again.'),
        );
      }
      // Log more details about the error
      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        print('Response Headers: ${e.response?.headers}');
        print('Request Data: ${e.requestOptions.data}');
      }
      
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
