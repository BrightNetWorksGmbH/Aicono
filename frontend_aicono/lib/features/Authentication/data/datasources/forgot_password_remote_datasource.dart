import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';

abstract class ForgotPasswordRemoteDataSource {
  Future<Either<Failure, String>> sendResetLink(String email);
}

class ForgotPasswordRemoteDataSourceImpl
    implements ForgotPasswordRemoteDataSource {
  final DioClient dioClient;

  ForgotPasswordRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, String>> sendResetLink(String email) async {
    try {
      final response = await dioClient.post(
        '/auth/forgot-password',
        data: {'email': email},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final message =
            response.data['message'] as String? ??
            'Password reset link sent successfully';
        return Right(message);
      } else {
        return Left(
          ServerFailure('Failed to send reset link: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
