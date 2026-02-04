import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/join_invite/domain/repositories/join_invite_repository.dart';

class JoinSwitchUseCase {
  final JoinInviteRepository repository;

  JoinSwitchUseCase({required this.repository});

  Future<Either<Failure, void>> call(String bryteswitchId) {
    return repository.joinSwitch(bryteswitchId);
  }
}
