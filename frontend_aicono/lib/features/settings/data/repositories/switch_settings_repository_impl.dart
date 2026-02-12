import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/settings/data/datasources/switch_settings_remote_datasource.dart';
import 'package:frontend_aicono/features/settings/domain/entities/switch_details_entity.dart';
import 'package:frontend_aicono/features/settings/domain/entities/update_switch_request.dart';
import 'package:frontend_aicono/features/settings/domain/repositories/switch_settings_repository.dart';

/// Implementation of [SwitchSettingsRepository].
class SwitchSettingsRepositoryImpl implements SwitchSettingsRepository {
  final SwitchSettingsRemoteDataSource remoteDataSource;

  SwitchSettingsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, SwitchDetailsEntity>> getSwitchById(
    String switchId,
  ) async {
    return remoteDataSource.getSwitchById(switchId);
  }

  @override
  Future<Either<Failure, SwitchDetailsEntity>> updateSwitch(
    String switchId,
    UpdateSwitchRequest request,
  ) async {
    return remoteDataSource.updateSwitch(switchId, request);
  }
}
