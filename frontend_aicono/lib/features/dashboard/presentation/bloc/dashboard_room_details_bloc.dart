import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_room_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_room_details_usecase.dart';

// Events
abstract class DashboardRoomDetailsEvent extends Equatable {
  const DashboardRoomDetailsEvent();

  @override
  List<Object?> get props => [];
}

class DashboardRoomDetailsRequested extends DashboardRoomDetailsEvent {
  final String roomId;
  final DashboardDetailsFilter? filter;

  const DashboardRoomDetailsRequested({required this.roomId, this.filter});

  @override
  List<Object?> get props => [roomId, filter];
}

class DashboardRoomDetailsReset extends DashboardRoomDetailsEvent {}

// States
abstract class DashboardRoomDetailsState extends Equatable {
  const DashboardRoomDetailsState();

  @override
  List<Object?> get props => [];
}

class DashboardRoomDetailsInitial extends DashboardRoomDetailsState {}

class DashboardRoomDetailsLoading extends DashboardRoomDetailsState {
  final String roomId;

  const DashboardRoomDetailsLoading({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

class DashboardRoomDetailsSuccess extends DashboardRoomDetailsState {
  final String roomId;
  final DashboardRoomDetails details;

  const DashboardRoomDetailsSuccess({
    required this.roomId,
    required this.details,
  });

  @override
  List<Object?> get props => [roomId, details];
}

class DashboardRoomDetailsFailure extends DashboardRoomDetailsState {
  final String roomId;
  final String message;

  const DashboardRoomDetailsFailure({
    required this.roomId,
    required this.message,
  });

  @override
  List<Object?> get props => [roomId, message];
}

// Bloc
class DashboardRoomDetailsBloc
    extends Bloc<DashboardRoomDetailsEvent, DashboardRoomDetailsState> {
  final GetDashboardRoomDetailsUseCase getDashboardRoomDetailsUseCase;

  DashboardRoomDetailsBloc({required this.getDashboardRoomDetailsUseCase})
    : super(DashboardRoomDetailsInitial()) {
    on<DashboardRoomDetailsRequested>(_onRequested);
    on<DashboardRoomDetailsReset>(
      (event, emit) => emit(DashboardRoomDetailsInitial()),
    );
  }

  Future<void> _onRequested(
    DashboardRoomDetailsRequested event,
    Emitter<DashboardRoomDetailsState> emit,
  ) async {
    emit(DashboardRoomDetailsLoading(roomId: event.roomId));

    final result = await getDashboardRoomDetailsUseCase(
      event.roomId,
      filter: event.filter,
    );
    result.fold(
      (failure) => emit(
        DashboardRoomDetailsFailure(
          roomId: event.roomId,
          message: _mapFailure(failure),
        ),
      ),
      (response) {
        final details = response.data;
        if (details == null) {
          emit(
            DashboardRoomDetailsFailure(
              roomId: event.roomId,
              message: 'Room details not found',
            ),
          );
          return;
        }
        emit(
          DashboardRoomDetailsSuccess(roomId: event.roomId, details: details),
        );
      },
    );
  }

  String _mapFailure(Failure failure) {
    if (failure is ServerFailure) return failure.message;
    if (failure is NetworkFailure) {
      return 'Network error. Please check your connection.';
    }
    if (failure is CacheFailure) return 'Cache error occurred.';
    return 'An unexpected error occurred.';
  }
}
