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
        '/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        await prefs.setString('user_data', user.toJsonString());

        // Save tokens to secure storage
        await SecureStorage.saveTokens(
          user.token, // Access token
          user.refreshToken, // Refresh token (or token if refreshToken not provided)
        );

        return Right(user);
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
      final response = await dioClient.get('/user/email/$email');

      if (response.statusCode == 200) {
        // User exists
        return const Right(true);
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
