import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';

abstract class InvitationRepository {
  Future<Either<Failure, InvitationEntity>> getInvitationByToken(String token);
  Future<Either<Failure, InvitationEntity>> getInvitationById(String id);
}
