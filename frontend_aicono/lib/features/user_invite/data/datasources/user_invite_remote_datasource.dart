import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/role_entity.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/invitation_request_entity.dart';

abstract class UserInviteRemoteDataSource {
  Future<Either<Failure, List<RoleEntity>>> getRoles(String bryteswitchId);
  Future<Either<Failure, void>> sendInvitation(InvitationRequestEntity request);
}

class UserInviteRemoteDataSourceImpl implements UserInviteRemoteDataSource {
  final DioClient dioClient;

  UserInviteRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, List<RoleEntity>>> getRoles(
    String bryteswitchId,
  ) async {
    try {
      final response = await dioClient.get(
        '/api/v1/roles/bryteswitch/$bryteswitchId',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['success'] == true) {
            // Expected: { success: true, data: { roles: [...], count, bryteswitch_id } }
            final dataObj = data['data'];
            if (dataObj is Map<String, dynamic>) {
              final rolesList = dataObj['roles'] as List?;
              if (rolesList != null) {
                final roles = rolesList
                    .whereType<Map<String, dynamic>>()
                    .map((e) => RoleEntity.fromJson(e))
                    .where((r) => r.id.isNotEmpty)
                    .toList();
                return Right(roles);
              }
            }
            return Right([]);
          }
          return Left(
            ServerFailure(
              (data['message'] ?? 'Failed to load roles.').toString(),
            ),
          );
        }
        return Left(ServerFailure('Invalid response format'));
      }
      return Left(ServerFailure('Get roles failed: ${response.statusCode}'));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Roles not found'));
      }
      if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check if the backend is running.',
          ),
        );
      }
      if (e.type == DioExceptionType.unknown) {
        final errorMessage =
            e.message ?? e.error?.toString() ?? 'Unknown network error';
        return Left(ServerFailure('Network error: $errorMessage'));
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> sendInvitation(
    InvitationRequestEntity request,
  ) async {
    try {
      final response = await dioClient.post(
        '/api/v1/invitations',
        data: request.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const Right(null);
      }
      final data = response.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return Left(ServerFailure(data['message'].toString()));
      }
      return Left(
        ServerFailure('Send invitation failed: ${response.statusCode}'),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['message'] != null) {
          return Left(ServerFailure(data['message'].toString()));
        }
      }
      if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check if the backend is running.',
          ),
        );
      }
      if (e.type == DioExceptionType.unknown) {
        final errorMessage =
            e.message ?? e.error?.toString() ?? 'Unknown network error';
        return Left(ServerFailure('Network error: $errorMessage'));
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
