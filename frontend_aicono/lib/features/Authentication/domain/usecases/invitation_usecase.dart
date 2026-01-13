import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/invitation_repository.dart';

class InvitationUseCase {
  final InvitationRepository repository;

  InvitationUseCase(this.repository);

  Future<Either<Failure, InvitationEntity>> getInvitationByToken(String token) {
    return repository.getInvitationByToken(token);
  }

  Future<Either<Failure, InvitationEntity>> getInvitationById(String id) {
    return repository.getInvitationById(id);
  }
}
