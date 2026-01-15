import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/loxone_room_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/repositories/complete_setup_repository.dart';

class GetLoxoneRoomsUseCase {
  final CompleteSetupRepository repository;

  GetLoxoneRoomsUseCase({required this.repository});

  Future<Either<Failure, LoxoneRoomsResponse>> call(
    String buildingId,
  ) async {
    return await repository.getLoxoneRooms(buildingId);
  }
}

