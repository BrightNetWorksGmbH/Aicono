import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/reset_password_entity.dart';

abstract class ResetPasswordRemoteDataSource {
  Future<Either<Failure, ResetPasswordResponse>> resetPassword(
    ResetPasswordRequest request,
  );
  Future<Either<Failure, ResetPasswordResponse>> forgotPassword(String email);
}

class ResetPasswordRemoteDataSourceImpl
    implements ResetPasswordRemoteDataSource {
  final DioClient dioClient;

  ResetPasswordRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, ResetPasswordResponse>> resetPassword(
    ResetPasswordRequest request,
  ) async {
    try {
      final response = await dioClient.put(
        '/api/users/reset-password',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final resetResponse = ResetPasswordResponse.fromJson(response.data);
        return Right(resetResponse);
      } else {
        return Left(
          ServerFailure('Reset password failed: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, ResetPasswordResponse>> forgotPassword(
    String email,
  ) async {
    try {
      final response = await dioClient.post(
        '/api/users/forgot-password',
        data: {'email': email},
      );

      if (response.statusCode == 200) {
        final resetResponse = ResetPasswordResponse.fromJson(response.data);
        return Right(resetResponse);
      } else {
        return Left(
          ServerFailure('Forgot password failed: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
