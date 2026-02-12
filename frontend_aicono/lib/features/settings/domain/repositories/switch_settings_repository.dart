import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/settings/domain/entities/switch_details_entity.dart';
import 'package:frontend_aicono/features/settings/domain/entities/update_switch_request.dart';

/// Repository interface for switch settings operations.
abstract class SwitchSettingsRepository {
  /// Fetches switch details by ID.
  Future<Either<Failure, SwitchDetailsEntity>> getSwitchById(String switchId);

  /// Updates switch with the given request.
  Future<Either<Failure, SwitchDetailsEntity>> updateSwitch(
    String switchId,
    UpdateSwitchRequest request,
  );
}
