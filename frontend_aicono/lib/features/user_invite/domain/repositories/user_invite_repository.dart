import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/role_entity.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/invitation_request_entity.dart';

abstract class UserInviteRepository {
  /// Fetches the list of roles available for the given Bryteswitch.
  Future<Either<Failure, List<RoleEntity>>> getRoles(String bryteswitchId);

  /// Sends an invitation to join the Bryteswitch.
  Future<Either<Failure, void>> sendInvitation(InvitationRequestEntity request);
}
