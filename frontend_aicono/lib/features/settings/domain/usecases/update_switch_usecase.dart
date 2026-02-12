import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/settings/domain/entities/switch_details_entity.dart';
import 'package:frontend_aicono/features/settings/domain/entities/update_switch_request.dart';
import 'package:frontend_aicono/features/settings/domain/repositories/switch_settings_repository.dart';

/// Use case for updating switch settings.
class UpdateSwitchUseCase {
  final SwitchSettingsRepository repository;

  UpdateSwitchUseCase({required this.repository});

  Future<Either<Failure, SwitchDetailsEntity>> call(
    String switchId,
    UpdateSwitchRequest request,
  ) {
    return repository.updateSwitch(switchId, request);
  }
}
