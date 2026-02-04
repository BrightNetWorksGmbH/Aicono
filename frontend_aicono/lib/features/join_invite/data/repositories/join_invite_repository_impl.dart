import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/join_invite/data/datasources/join_invite_remote_datasource.dart';
import 'package:frontend_aicono/features/join_invite/domain/repositories/join_invite_repository.dart';

class JoinInviteRepositoryImpl implements JoinInviteRepository {
  final JoinInviteRemoteDataSource remoteDataSource;

  JoinInviteRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> joinSwitch(String bryteswitchId) {
    return remoteDataSource.joinSwitch(bryteswitchId);
  }
}
