import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class SendBryteSightInvitationUseCase {
  final VerseRepository repository;

  SendBryteSightInvitationUseCase({required this.repository});

  Future<Either<Failure, void>> call(
    String verseId,
    String recipientEmail,
  ) async {
    return await repository.sendBryteSightInvitation(verseId, recipientEmail);
  }
}
