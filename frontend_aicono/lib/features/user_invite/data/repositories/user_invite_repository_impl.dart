import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/user_invite/data/datasources/user_invite_remote_datasource.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/role_entity.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/invitation_request_entity.dart';
import 'package:frontend_aicono/features/user_invite/domain/repositories/user_invite_repository.dart';

class UserInviteRepositoryImpl implements UserInviteRepository {
  final UserInviteRemoteDataSource remoteDataSource;

  UserInviteRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<RoleEntity>>> getRoles(
    String bryteswitchId,
  ) async {
    return remoteDataSource.getRoles(bryteswitchId);
  }

  @override
  Future<Either<Failure, void>> sendInvitation(
    InvitationRequestEntity request,
  ) async {
    return remoteDataSource.sendInvitation(request);
  }
}
