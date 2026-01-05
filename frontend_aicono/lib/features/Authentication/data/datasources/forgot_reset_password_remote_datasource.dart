import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';

abstract class ForgotResetPasswordRemoteDataSource {
  Future<Either<Failure, String>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  });
}

class ForgotResetPasswordRemoteDataSourceImpl
    implements ForgotResetPasswordRemoteDataSource {
  final DioClient dioClient;

  ForgotResetPasswordRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, String>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await dioClient.post(
        '/api/v1/auth/reset-password',
        data: {
          'token': token,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final message =
            response.data['message'] as String? ??
            'Password reset successfully';
        return Right(message);
      } else {
        return Left(
          ServerFailure('Failed to reset password: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
