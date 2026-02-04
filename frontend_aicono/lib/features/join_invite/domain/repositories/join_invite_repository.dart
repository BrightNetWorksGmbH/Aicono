import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';

abstract class JoinInviteRepository {
  /// Join a Bryteswitch (switch) using its ID.
  Future<Either<Failure, void>> joinSwitch(String bryteswitchId);
}
