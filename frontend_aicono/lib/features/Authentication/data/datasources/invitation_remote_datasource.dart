import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

abstract class InvitationRemoteDataSource {
  Future<Either<Failure, InvitationEntity>> getInvitationByToken(String token);
  Future<Either<Failure, InvitationEntity>> getInvitationById(String id);
}

class InvitationRemoteDataSourceImpl implements InvitationRemoteDataSource {
  final DioClient dioClient;

  InvitationRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, InvitationEntity>> getInvitationByToken(
    String token,
  ) async {
    try {
      final response = await dioClient.get('/api/v1/invitations/token/$token');

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Check for success flag
        if (responseData['success'] == true && responseData['data'] != null) {
          final invitationData = responseData['data']['invitation'];

          if (invitationData != null) {
            // Add token from URL to the invitation data since it's not in the response
            final invitationDataWithToken = Map<String, dynamic>.from(
              invitationData,
            );
            invitationDataWithToken['token'] = token;

            final invitation = InvitationEntity.fromJson(
              invitationDataWithToken,
            );
            return Right(invitation);
          } else {
            return Left(
              ServerFailure('Invalid response format: missing invitation data'),
            );
          }
        } else {
          return Left(
            ServerFailure(
              'Invalid response format: success flag is false or data is missing',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure('Get invitation failed: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Invitation not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check if the backend server is running.',
          ),
        );
      } else if (e.type == DioExceptionType.unknown) {
        // Handle unknown errors (often SSL, network, or URL issues)
        final errorMessage =
            e.message ?? e.error?.toString() ?? 'Unknown network error';
        return Left(
          ServerFailure(
            'Network error: $errorMessage. Please check your internet connection and try again.',
          ),
        );
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, InvitationEntity>> getInvitationById(
    String id,
  ) async {
    try {
      final response = await dioClient.get('/api/v1/invitations/$id');

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Check for success flag
        if (responseData['success'] == true && responseData['data'] != null) {
          final invitationData = responseData['data']['invitation'];

          if (invitationData != null) {
            final invitation = InvitationEntity.fromJson(invitationData);
            return Right(invitation);
          } else {
            return Left(
              ServerFailure('Invalid response format: missing invitation data'),
            );
          }
        } else {
          return Left(
            ServerFailure(
              'Invalid response format: success flag is false or data is missing',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure('Get invitation failed: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Invitation not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check if the backend server is running.',
          ),
        );
      } else if (e.type == DioExceptionType.unknown) {
        // Handle unknown errors (often SSL, network, or URL issues)
        final errorMessage =
            e.message ?? e.error?.toString() ?? 'Unknown network error';
        return Left(
          ServerFailure(
            'Network error: $errorMessage. Please check your internet connection and try again.',
          ),
        );
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
