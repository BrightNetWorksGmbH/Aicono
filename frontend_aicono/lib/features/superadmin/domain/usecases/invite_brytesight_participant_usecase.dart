import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class InviteBryteSightParticipantUseCase {
  final VerseRepository repository;

  InviteBryteSightParticipantUseCase({required this.repository});

  Future<Either<Failure, void>> call({
    required String verseId,
    required String email,
    required String bryteSightId,
    required String firstName,
    required String lastName,
  }) async {
    return await repository.inviteBryteSightParticipant(
      verseId: verseId,
      email: email,
      bryteSightId: bryteSightId,
      firstName: firstName,
      lastName: lastName,
    );
  }
}
