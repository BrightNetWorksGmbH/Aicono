import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/data/datasources/complete_setup_remote_data_source.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/complete_setup_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class CompleteSetupRepositoryImpl implements CompleteSetupRepository {
  final CompleteSetupRemoteDataSource remoteDataSource;

  CompleteSetupRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, CompleteSetupResponse>> completeSetup(
    String switchId,
    CompleteSetupRequest request,
  ) async {
    return await remoteDataSource.completeSetup(switchId, request);
  }
}
