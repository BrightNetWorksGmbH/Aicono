import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/network/dio_client.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/admin_entity.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';

abstract class VerseRemoteDataSource {
  Future<Either<Failure, CreateVerseResponse>> createVerse(
    CreateVerseRequest request,
  );
  Future<Either<Failure, List<VerseEntity>>> getAllVerses();
  Future<Either<Failure, void>> deleteVerse(String verseId);
  Future<Either<Failure, List<AdminEntity>>> getVerseAdmins(String verseId);
  Future<Either<Failure, void>> setBryteSightProvisioning(
    String verseId,
    bool canCreateBrytesight,
  );
  Future<Either<Failure, void>> sendBryteSightInvitation(
    String verseId,
    String recipientEmail,
  );

  Future<Either<Failure, String>> getBryteSightIdByVerse(String verseId);
  Future<Either<Failure, void>> updateBryteSightMember({
    required String bryteSightId,
    required String memberUserId,
    required String action,
  });
  Future<Either<Failure, void>> inviteBryteSightParticipant({
    required String verseId,
    required String email,
    required String bryteSightId,
    required String firstName,
    required String lastName,
  });
}

class VerseRemoteDataSourceImpl implements VerseRemoteDataSource {
  final DioClient dioClient;

  VerseRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Either<Failure, CreateVerseResponse>> createVerse(
    CreateVerseRequest request,
  ) async {
    try {
      final response = await dioClient.post(
        '/api/v1/bryteswitch/create-initial',
        data: request.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final createResponse = CreateVerseResponse.fromJson(response.data);
        return Right(createResponse);
      } else {
        return Left(
          ServerFailure('Failed to create verse: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<VerseEntity>>> getAllVerses() async {
    try {
      // Fetch all pages from the API (default page size is 50)
      int page = 1;
      const int limit = 100; // use a higher limit to reduce number of requests
      bool hasMore = true;
      final List<VerseEntity> allVerses = [];

      while (hasMore) {
        final response = await dioClient.get(
          '/verse/list',
          queryParameters: {'page': page, 'limit': limit},
        );

        if (response.statusCode == 200) {
          final List<dynamic> versesData =
              response.data['verses'] as List<dynamic>;
          final List<VerseEntity> pageVerses = versesData.map((verseJson) {
            return VerseEntity(
              id: verseJson['_id'] as String,
              name: verseJson['name'] as String,
              subdomain: verseJson['subdomain'] as String?,
              organizationName: verseJson['organization_name'] as String?,
              adminEmail: verseJson['admin_email'] as String? ?? '',
              isSetupComplete: verseJson['is_setup_complete'] as bool? ?? false,
              canCreateBrytesight:
                  verseJson['can_create_brytesight'] as bool? ?? false,
              createdAt: DateTime.parse(verseJson['created_at'] as String),
              updatedAt: verseJson['updated_at'] != null
                  ? DateTime.parse(verseJson['updated_at'] as String)
                  : null,
            );
          }).toList();

          allVerses.addAll(pageVerses);

          final pagination =
              response.data['pagination'] as Map<String, dynamic>?;
          hasMore = pagination != null
              ? (pagination['has_more'] as bool? ?? false)
              : false;
          page += 1;
        } else {
          return Left(
            ServerFailure('Failed to fetch verses: ${response.statusCode}'),
          );
        }
      }

      return Right(allVerses);
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteVerse(String verseId) async {
    try {
      final response = await dioClient.delete('/verse/$verseId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return const Right(null);
      } else {
        return Left(
          ServerFailure('Failed to delete verse: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AdminEntity>>> getVerseAdmins(
    String verseId,
  ) async {
    try {
      final response = await dioClient.get('/verses/$verseId/admins');

      if (response.statusCode == 200) {
        final List<dynamic> adminsData =
            response.data['admins'] as List<dynamic>;
        final admins = adminsData.map((adminJson) {
          return AdminEntity(
            id: adminJson['_id'] as String,
            firstName: adminJson['first_name'] as String,
            lastName: adminJson['last_name'] as String,
            email: adminJson['email'] as String,
          );
        }).toList();
        return Right(admins);
      } else {
        return Left(
          ServerFailure('Failed to fetch admins: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> setBryteSightProvisioning(
    String verseId,
    bool canCreateBrytesight,
  ) async {
    try {
      final response = await dioClient.put(
        '/verses/$verseId/brytesight-provisioning',
        data: {'can_create_brytesight': canCreateBrytesight},
      );

      if (response.statusCode == 200) {
        return const Right(null);
      } else {
        return Left(
          ServerFailure(
            'Failed to update provisioning: ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> sendBryteSightInvitation(
    String verseId,
    String recipientEmail,
  ) async {
    try {
      final response = await dioClient.post(
        '/brytesight/create-invite',
        data: {'verse_id': verseId, 'recipient_email': recipientEmail},
      );

      if (response.statusCode == 201) {
        return const Right(null);
      } else {
        return Left(
          ServerFailure('Failed to send invitation: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> getBryteSightIdByVerse(String verseId) async {
    try {
      final response = await dioClient.get('/brytesight/verse/$verseId');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final brytesight = data['brytesight'] as Map<String, dynamic>;
        final id = brytesight['_id'] as String;
        return Right(id);
      } else {
        return Left(
          ServerFailure('Failed to fetch BryteSight: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateBryteSightMember({
    required String bryteSightId,
    required String memberUserId,
    required String action,
  }) async {
    try {
      final response = await dioClient.put(
        '/brytesight/$bryteSightId/members/$memberUserId',
        data: {'action': action},
      );

      if (response.statusCode == 200) {
        return const Right(null);
      } else {
        return Left(
          ServerFailure('Failed to update member: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> inviteBryteSightParticipant({
    required String verseId,
    required String email,
    required String bryteSightId,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await dioClient.post(
        '/brytesight/invitations',
        data: {
          'verse_id': verseId,
          'email': email,
          'brytesight_id': bryteSightId,
          'first_name': firstName,
          'last_name': lastName,
        },
      );
      print(response.statusCode);
      print(response.data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return const Right(null);
      } else {
        return Left(
          ServerFailure('Failed to invite participant: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return Left(ServerFailure(ErrorExtractor.extractServerMessage(e)));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
