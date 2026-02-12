import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';

/// Calls POST /api/v1/auth/change-password
abstract class ChangePasswordRemoteDataSource {
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
  );
}

class ChangePasswordRemoteDataSourceImpl
    implements ChangePasswordRemoteDataSource {
  final DioClient dioClient;

  ChangePasswordRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Change Password Request');
      }

      final response = await dioClient.post(
        '/api/v1/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return const Right(null);
      }
      final data = response.data;
      final msg = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Failed to change password';
      return Left(ServerFailure(msg));
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Change password error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
