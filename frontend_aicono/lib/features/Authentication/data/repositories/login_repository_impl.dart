import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/storage/secure_storage.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginRepositoryImpl implements LoginRepository {
  final DioClient dioClient;
  final SharedPreferences prefs;

  LoginRepositoryImpl({required this.dioClient, required this.prefs});

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    try {
      // Make API call to login endpoint
      final response = await dioClient.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Check for success flag and data wrapper
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          final userData = data['user'];
          final token = data['token'] ?? '';

          // Combine user data with token and other fields from data
          final combinedUserData = Map<String, dynamic>.from(userData);
          combinedUserData['token'] = token;
          combinedUserData['refresh_token'] =
              token; // Use same token as refresh if not provided

          // Handle roles array - extract bryteswitch_id for joinedVerse
          if (data['roles'] != null && data['roles'] is List) {
            final roles = data['roles'] as List;
            final joinedVerse = roles
                .where((role) => role['bryteswitch_id'] != null)
                .map((role) => role['bryteswitch_id'].toString())
                .toList();
            combinedUserData['joined_verse'] = joinedVerse;
          }

          // Add is_setup_complete if present
          if (data['is_setup_complete'] != null) {
            combinedUserData['is_setup_complete'] = data['is_setup_complete'];
          }

          final user = User.fromJson(combinedUserData);
          await prefs.setString('user_data', user.toJsonString());

          // Save tokens to secure storage
          await SecureStorage.saveTokens(
            user.token, // Access token
            user.refreshToken, // Refresh token (or token if refreshToken not provided)
          );

          return Right(user);
        } else {
          return Left(
            ServerFailure(
              'Invalid response format: success flag is false or data is missing',
            ),
          );
        }
      } else {
        return Left(ServerFailure('Login failed: ${response.statusCode}'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // Make API call to logout endpoint
      final response = await dioClient.post('/logout');

      if (response.statusCode == 200) {
        // Clear user data from local storage on logout
        await prefs.remove('user_data');
        return const Right(null);
      } else {
        return Left(ServerFailure('Logout failed: ${response.statusCode}'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      // Get user data from local storage
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final user = User.fromJsonString(userDataString);
        return Right(user);
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Get current user error: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> checkUserExists(String email) async {
    try {
      final response = await dioClient.get('/api/v1/auth/user/email/$email');

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Check for success flag and data wrapper
        if (responseData['success'] == true && responseData['data'] != null) {
          // User exists
          return const Right(true);
        } else {
          // User doesn't exist or invalid response
          return const Right(false);
        }
      } else if (response.statusCode == 404) {
        // User doesn't exist
        return const Right(false);
      } else {
        return Left(ServerFailure('Check user failed: ${response.statusCode}'));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // User doesn't exist
        return const Right(false);
      } else if (e.response?.statusCode == 401) {
        // Unauthorized - this endpoint requires auth
        // For now, assume user doesn't exist and let them proceed to registration
        return const Right(false);
      }
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, User>> fetchProfile() async {
    try {
      // Make API call to profile endpoint
      final response = await dioClient.get('/profile');

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);

        // Update local storage with fresh user data
        await prefs.setString('user_data', user.toJsonString());

        return Right(user);
      } else {
        return Left(
          ServerFailure('Fetch profile failed: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
