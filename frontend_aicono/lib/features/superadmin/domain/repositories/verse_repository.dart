import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/admin_entity.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';

abstract class VerseRepository {
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

  // BryteSight
  Future<Either<Failure, String>> getBryteSightIdByVerse(String verseId);
  Future<Either<Failure, void>> updateBryteSightMember({
    required String bryteSightId,
    required String memberUserId,
    required String action, // 'add' | 'remove'
  });

  Future<Either<Failure, void>> inviteBryteSightParticipant({
    required String verseId,
    required String email,
    required String bryteSightId,
    required String firstName,
    required String lastName,
  });
}
