import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/settings/domain/entities/switch_details_entity.dart';
import 'package:frontend_aicono/features/settings/domain/repositories/switch_settings_repository.dart';

/// Use case for fetching switch details by ID.
class GetSwitchByIdUseCase {
  final SwitchSettingsRepository repository;

  GetSwitchByIdUseCase({required this.repository});

  Future<Either<Failure, SwitchDetailsEntity>> call(String switchId) {
    return repository.getSwitchById(switchId);
  }
}
