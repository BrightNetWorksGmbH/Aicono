import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';

abstract class JoinInviteRemoteDataSource {
  Future<Either<Failure, void>> joinSwitch(String bryteswitchId);
}

class JoinInviteRemoteDataSourceImpl implements JoinInviteRemoteDataSource {
  final DioClient dioClient;

  JoinInviteRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, void>> joinSwitch(String bryteswitchId) async {
    try {
      final response = await dioClient.post(
        '/api/v1/bryteswitch/$bryteswitchId/join',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const Right(null);
      }

      final data = response.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return Left(ServerFailure(data['message'].toString()));
      }

      return Left(ServerFailure('Join switch failed: ${response.statusCode}'));
    } on DioException catch (e) {
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
