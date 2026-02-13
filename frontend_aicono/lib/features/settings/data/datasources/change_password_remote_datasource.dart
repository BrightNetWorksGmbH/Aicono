import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';

/// Calls PUT /api/v1/users/me/password
/// Body: { current_password, new_password, confirm_password }
abstract class ChangePasswordRemoteDataSource {
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
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
    String confirmPassword,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Change Password Request: PUT /api/v1/users/me/password');
      }

      final response = await dioClient.put(
        '/api/v1/users/me/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
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
