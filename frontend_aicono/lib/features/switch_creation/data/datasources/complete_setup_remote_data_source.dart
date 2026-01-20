import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/complete_setup_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/loxone_connection_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/loxone_room_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/save_floor_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_floors_entity.dart';

abstract class CompleteSetupRemoteDataSource {
  Future<Either<Failure, CompleteSetupResponse>> completeSetup(
    String switchId,
    CompleteSetupRequest request,
  );

  Future<Either<Failure, CreateSiteResponse>> createSite(
    String switchId,
    CreateSiteRequest request,
  );

  Future<Either<Failure, GetSiteResponse>> getSite(String siteId);

  Future<Either<Failure, CreateBuildingsResponse>> createBuildings(
    String siteId,
    CreateBuildingsRequest request,
  );

  Future<Either<Failure, GetBuildingsResponse>> getBuildings(String siteId);

  Future<Either<Failure, LoxoneConnectionResponse>> connectLoxone(
    String buildingId,
    LoxoneConnectionRequest request,
  );

  Future<Either<Failure, LoxoneRoomsResponse>> getLoxoneRooms(
    String buildingId,
  );

  Future<Either<Failure, SaveFloorResponse>> saveFloor(
    String buildingId,
    SaveFloorRequest request,
  );

  Future<Either<Failure, GetFloorsResponse>> getFloors(String buildingId);
}

class CompleteSetupRemoteDataSourceImpl
    implements CompleteSetupRemoteDataSource {
  final DioClient dioClient;

  CompleteSetupRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, CompleteSetupResponse>> completeSetup(
    String switchId,
    CompleteSetupRequest request,
  ) async {
    try {
      final requestData = request.toJson();

      // Debug: Print the exact JSON being sent
      if (kDebugMode) {
        print('📤 Complete Setup Request Data:');
        print('Switch ID: $switchId');
        print('Request JSON: $requestData');
        // Print formatted JSON for easier debugging
        try {
          final jsonString = jsonEncode(requestData);
          print('Formatted JSON: $jsonString');
        } catch (e) {
          print('Error encoding JSON: $e');
        }
      }

      // Pass Map directly - Dio will serialize it automatically
      // This matches the pattern used in register_user_remote_datasource and login_repository_impl
      final response = await dioClient.post(
        '/api/v1/bryteswitch/$switchId/complete-setup',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        // Check for success flag
        if (responseData['success'] == true) {
          final completeSetupResponse = CompleteSetupResponse.fromJson(
            responseData,
          );
          return Right(completeSetupResponse);
        } else {
          return Left(
            ServerFailure(
              responseData['message'] ??
                  'Setup completion failed. Please try again.',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            'Setup completion failed with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Switch not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }
      // Log more details about the error
      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        print('Response Headers: ${e.response?.headers}');
        print('Request Data: ${e.requestOptions.data}');
      }

      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, CreateSiteResponse>> createSite(
    String switchId,
    CreateSiteRequest request,
  ) async {
    try {
      final requestData = request.toJson();

      // Debug: Print the exact JSON being sent
      if (kDebugMode) {
        print('📤 Create Site Request Data:');
        print('Switch ID: $switchId');
        print('Request JSON: $requestData');
        try {
          final jsonString = jsonEncode(requestData);
          print('Formatted JSON: $jsonString');
        } catch (e) {
          print('Error encoding JSON: $e');
        }
      }

      final response = await dioClient.post(
        '/api/v1/sites/bryteswitch/$switchId',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        // Check for success flag
        if (responseData['success'] == true ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final createSiteResponse = CreateSiteResponse.fromJson(
            responseData is Map<String, dynamic>
                ? responseData
                : {'success': true, 'data': responseData},
          );
          return Right(createSiteResponse);
        } else {
          return Left(
            ServerFailure(
              responseData['message'] ??
                  'Site creation failed. Please try again.',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            'Site creation failed with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Switch not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }
      // Log more details about the error
      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        print('Response Headers: ${e.response?.headers}');
        print('Request Data: ${e.requestOptions.data}');
      }

      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, GetSiteResponse>> getSite(String siteId) async {
    try {
      // Debug: Print the request
      if (kDebugMode) {
        print('📤 Get Site Request:');
        print('Site ID: $siteId');
      }

      final response = await dioClient.get('/api/v1/sites/$siteId');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true || response.statusCode == 200) {
          final getSiteResponse = GetSiteResponse.fromJson(
            responseData is Map<String, dynamic>
                ? responseData
                : {'success': true, 'data': responseData},
          );
          return Right(getSiteResponse);
        } else {
          return Left(
            ServerFailure(
              responseData['message'] ??
                  'Failed to fetch site. Please try again.',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            'Failed to fetch site with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Site not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }
      // Log more details about the error
      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        print('Response Headers: ${e.response?.headers}');
      }

      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, CreateBuildingsResponse>> createBuildings(
    String siteId,
    CreateBuildingsRequest request,
  ) async {
    try {
      final requestData = request.toJson();

      // Debug: Print the exact JSON being sent
      if (kDebugMode) {
        print('📤 Create Buildings Request Data:');
        print('Site ID: $siteId');
        print('Request JSON: $requestData');
        try {
          final jsonString = jsonEncode(requestData);
          print('Formatted JSON: $jsonString');
        } catch (e) {
          print('Error encoding JSON: $e');
        }
      }

      final response = await dioClient.post(
        '/api/v1/buildings/site/$siteId',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        // Check for success flag
        if (responseData['success'] == true ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final createBuildingsResponse = CreateBuildingsResponse.fromJson(
            responseData is Map<String, dynamic>
                ? responseData
                : {'success': true, 'data': responseData},
          );
          return Right(createBuildingsResponse);
        } else {
          return Left(
            ServerFailure(
              responseData['message'] ??
                  'Buildings creation failed. Please try again.',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            'Buildings creation failed with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Site not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }
      // Log more details about the error
      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        print('Response Headers: ${e.response?.headers}');
        print('Request Data: ${e.requestOptions.data}');
      }

      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, GetBuildingsResponse>> getBuildings(
    String siteId,
  ) async {
    try {
      // Debug: Print the request
      if (kDebugMode) {
        print('📤 Get Buildings Request:');
        print('Site ID: $siteId');
      }

      final response = await dioClient.get('/api/v1/buildings/site/$siteId');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true || response.statusCode == 200) {
          final getBuildingsResponse = GetBuildingsResponse.fromJson(
            responseData is Map<String, dynamic>
                ? responseData
                : {'success': true, 'data': responseData},
          );
          return Right(getBuildingsResponse);
        } else {
          return Left(
            ServerFailure(
              responseData['message'] ??
                  'Failed to fetch buildings. Please try again.',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            'Failed to fetch buildings with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Site not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }
      // Log more details about the error
      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        print('Response Headers: ${e.response?.headers}');
      }

      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, LoxoneConnectionResponse>> connectLoxone(
    String buildingId,
    LoxoneConnectionRequest request,
  ) async {
    try {
      final requestData = request.toJson();

      // Debug: Print the exact JSON being sent
      if (kDebugMode) {
        print('📤 Connect Loxone Request Data:');
        print('Building ID: $buildingId');
        print('Request JSON: $requestData');
        try {
          final jsonString = jsonEncode(requestData);
          print('Formatted JSON: $jsonString');
        } catch (e) {
          print('Error encoding JSON: $e');
        }
      }

      final response = await dioClient.post(
        '/api/v1/loxone/connect/$buildingId',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        // Check for success flag
        if (responseData['success'] == true ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final loxoneConnectionResponse = LoxoneConnectionResponse.fromJson(
            responseData is Map<String, dynamic>
                ? responseData
                : {'success': true, 'data': responseData},
          );
          return Right(loxoneConnectionResponse);
        } else {
          return Left(
            ServerFailure(
              responseData['message'] ??
                  'Loxone connection failed. Please try again.',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            'Loxone connection failed with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Building not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }
      // Log more details about the error
      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        print('Response Headers: ${e.response?.headers}');
        print('Request Data: ${e.requestOptions.data}');
      }

      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, LoxoneRoomsResponse>> getLoxoneRooms(
    String buildingId,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Get Loxone Rooms Request:');
        print('Building ID: $buildingId');
      }

      final response = await dioClient.get('/api/v1/loxone/rooms/$buildingId');

      if (response.statusCode == 200) {
        final responseData = response.data;

        // The API returns an array directly, not wrapped in an object
        final loxoneRoomsResponse = LoxoneRoomsResponse.fromJson(responseData);
        return Right(loxoneRoomsResponse);
      } else {
        return Left(
          ServerFailure(
            'Failed to fetch rooms with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Building not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }

      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
      }

      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, SaveFloorResponse>> saveFloor(
    String buildingId,
    SaveFloorRequest request,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Save Floor Request:');
        print('Building ID: $buildingId');
        print('Request: ${request.toJson()}');
      }

      final requestData = request.toJson();

      final response = await dioClient.post(
        '/api/v1/floors/building/$buildingId',
        data: requestData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        if (responseData['success'] == true ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final saveFloorResponse = SaveFloorResponse.fromJson(
            responseData is Map<String, dynamic>
                ? responseData
                : {'success': true, 'data': responseData},
          );
          return Right(saveFloorResponse);
        } else {
          return Left(
            ServerFailure(
              responseData['message'] ??
                  'Failed to save floor. Please try again.',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            'Failed to save floor with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Building not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure(
            'Cannot connect to server. Please check your internet connection.',
          ),
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(ServerFailure('Request timed out. Please try again.'));
      }

      if (kDebugMode && e.response != null) {
        print('❌ Server Error Details:');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
      }

      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
      }
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, GetFloorsResponse>> getFloors(
    String buildingId,
  ) async {
    try {
      if (kDebugMode) {
        print('📤 Get Floors Request:');
        print('Building ID: $buildingId');
      }

      final response = await dioClient.get(
        '/api/v1/dashboard/floors/$buildingId',
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (kDebugMode) {
          print('📥 Get Floors Response:');
          print(responseData);
        }

        // Handle both array response and wrapped response
        final getFloorsResponse = GetFloorsResponse.fromJson(
          responseData is List
              ? responseData
              : (responseData is Map<String, dynamic>
                    ? responseData
                    : {'data': responseData}),
        );

        return Right(getFloorsResponse);
      } else {
        return Left(
          ServerFailure(
            'Failed to get floors with status ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(ServerFailure('Building not found'));
      } else if (e.type == DioExceptionType.connectionError) {
        return Left(
          ServerFailure('Connection error. Please check your internet.'),
        );
      } else {
        return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
      }
    } catch (e) {
      return Left(ServerFailure('Failed to get floors: ${e.toString()}'));
    }
  }
}
