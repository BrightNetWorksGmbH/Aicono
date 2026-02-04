import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/invitation_request_entity.dart';
import 'package:frontend_aicono/features/user_invite/domain/repositories/user_invite_repository.dart';

class SendInvitationUseCase {
  final UserInviteRepository repository;

  SendInvitationUseCase({required this.repository});

  Future<Either<Failure, void>> call(InvitationRequestEntity request) async {
    return repository.sendInvitation(request);
  }
}
