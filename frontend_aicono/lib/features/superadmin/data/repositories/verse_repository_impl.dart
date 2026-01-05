import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/data/datasources/verse_remote_datasource.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/admin_entity.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class VerseRepositoryImpl implements VerseRepository {
  final VerseRemoteDataSource remoteDataSource;

  VerseRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, CreateVerseResponse>> createVerse(
    CreateVerseRequest request,
  ) async {
    return await remoteDataSource.createVerse(request);
  }

  @override
  Future<Either<Failure, List<VerseEntity>>> getAllVerses() async {
    return await remoteDataSource.getAllVerses();
  }

  @override
  Future<Either<Failure, void>> deleteVerse(String verseId) async {
    return await remoteDataSource.deleteVerse(verseId);
  }

  @override
  Future<Either<Failure, List<AdminEntity>>> getVerseAdmins(
    String verseId,
  ) async {
    return await remoteDataSource.getVerseAdmins(verseId);
  }

  @override
  Future<Either<Failure, void>> setBryteSightProvisioning(
    String verseId,
    bool canCreateBrytesight,
  ) async {
    return await remoteDataSource.setBryteSightProvisioning(
      verseId,
      canCreateBrytesight,
    );
  }

  @override
  Future<Either<Failure, void>> sendBryteSightInvitation(
    String verseId,
    String recipientEmail,
  ) async {
    return await remoteDataSource.sendBryteSightInvitation(
      verseId,
      recipientEmail,
    );
  }

  @override
  Future<Either<Failure, String>> getBryteSightIdByVerse(String verseId) async {
    return await remoteDataSource.getBryteSightIdByVerse(verseId);
  }

  @override
  Future<Either<Failure, void>> updateBryteSightMember({
    required String bryteSightId,
    required String memberUserId,
    required String action,
  }) async {
    return await remoteDataSource.updateBryteSightMember(
      bryteSightId: bryteSightId,
      memberUserId: memberUserId,
      action: action,
    );
  }

  @override
  Future<Either<Failure, void>> inviteBryteSightParticipant({
    required String verseId,
    required String email,
    required String bryteSightId,
    required String firstName,
    required String lastName,
  }) async {
    return await remoteDataSource.inviteBryteSightParticipant(
      verseId: verseId,
      email: email,
      bryteSightId: bryteSightId,
      firstName: firstName,
      lastName: lastName,
    );
  }
}
