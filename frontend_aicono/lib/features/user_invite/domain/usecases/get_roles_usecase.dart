import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/role_entity.dart';
import 'package:frontend_aicono/features/user_invite/domain/repositories/user_invite_repository.dart';

class GetRolesUseCase {
  final UserInviteRepository repository;

  GetRolesUseCase({required this.repository});

  Future<Either<Failure, List<RoleEntity>>> call(String bryteswitchId) async {
    return repository.getRoles(bryteswitchId);
  }
}
