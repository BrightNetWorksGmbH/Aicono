import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_room_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardRoomDetailsUseCase {
  final DashboardRepository repository;

  GetDashboardRoomDetailsUseCase({required this.repository});

  Future<Either<Failure, DashboardRoomDetailsResponse>> call(String roomId) async {
    return repository.getRoomDetails(roomId);
  }
}
