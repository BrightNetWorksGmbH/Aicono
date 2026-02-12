import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/features/settings/domain/entities/profile_update_request.dart';

/// Remote data source for profile API: GET/PUT /api/v1/users/me
abstract class ProfileRemoteDataSource {
  Future<Either<Failure, User>> getProfile();
  Future<Either<Failure, User>> updateProfile(ProfileUpdateRequest request);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final DioClient dioClient;

  ProfileRemoteDataSourceImpl({required this.dioClient});

  User _mergeWithCurrentUser(User profileUser) {
    final current = sl<AuthService>().currentUser;
    if (current == null) return profileUser;
    // Preserve token, refreshToken, joinedVerse, roles, pendingInvitations
    return User(
      id: profileUser.id,
      email: profileUser.email,
      passwordHash: profileUser.passwordHash,
      firstName: profileUser.firstName,
      lastName: profileUser.lastName,
      avatarUrl: profileUser.avatarUrl,
      phoneNumber: profileUser.phoneNumber ?? current.phoneNumber,
      position: profileUser.position,
      isActive: profileUser.isActive,
      isSuperAdmin: profileUser.isSuperAdmin,
      lastLogin: profileUser.lastLogin,
      createdAt: profileUser.createdAt,
      updatedAt: profileUser.updatedAt,
      joinedVerse: current.joinedVerse.isNotEmpty
          ? current.joinedVerse
          : profileUser.joinedVerse,
      roles: current.roles.isNotEmpty ? current.roles : profileUser.roles,
      token: current.token.isNotEmpty ? current.token : profileUser.token,
      refreshToken: current.refreshToken.isNotEmpty
          ? current.refreshToken
          : profileUser.refreshToken,
      pendingInvitations: current.pendingInvitations.isNotEmpty
          ? current.pendingInvitations
          : profileUser.pendingInvitations,
    );
  }

  Map<String, dynamic> _normalizeUserJson(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    if (map['profile_picture_url'] != null && map['avatar_url'] == null) {
      map['avatar_url'] = map['profile_picture_url'];
    }
    return map;
  }

  @override
  Future<Either<Failure, User>> getProfile() async {
    try {
      if (kDebugMode) {
        print('📤 Get Profile Request: /api/v1/users/me');
      }

      final response = await dioClient.get('/api/v1/users/me');

      if (response.statusCode == 200) {
        final responseData = response.data;
        Map<String, dynamic> userData;
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData['data'] != null) {
            userData = Map<String, dynamic>.from(responseData['data'] as Map);
          } else {
            userData = responseData;
          }
        } else {
          return Left(ServerFailure('Invalid response format'));
        }

        userData = _normalizeUserJson(userData);
        final user = _mergeWithCurrentUser(User.fromJson(userData));
        return Right(user);
      }
      return Left(
        ServerFailure('Failed to fetch profile with status ${response.statusCode}'),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Profile not found'));
      }
      if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Get profile error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile(
    ProfileUpdateRequest request,
  ) async {
    try {
      final requestData = request.toJson();
      if (kDebugMode) {
        print('📤 Update Profile Request: /api/v1/users/me, data=$requestData');
      }

      final response = await dioClient.put(
        '/api/v1/users/me',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        Map<String, dynamic> userData;
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData['data'] != null) {
            userData = Map<String, dynamic>.from(responseData['data'] as Map);
          } else {
            userData = responseData;
          }
        } else {
          return Left(ServerFailure('Invalid response format'));
        }

        userData = _normalizeUserJson(userData);
        final user = _mergeWithCurrentUser(User.fromJson(userData));
        return Right(user);
      }
      return Left(
        ServerFailure(
          'Failed to update profile with status ${response.statusCode}',
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Profile not found'));
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Update profile error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
