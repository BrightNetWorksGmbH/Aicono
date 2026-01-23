import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_floor_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_floor_details_usecase.dart';

// Events
abstract class DashboardFloorDetailsEvent extends Equatable {
  const DashboardFloorDetailsEvent();

  @override
  List<Object?> get props => [];
}

class DashboardFloorDetailsRequested extends DashboardFloorDetailsEvent {
  final String floorId;

  const DashboardFloorDetailsRequested({required this.floorId});

  @override
  List<Object?> get props => [floorId];
}

class DashboardFloorDetailsReset extends DashboardFloorDetailsEvent {}

// States
abstract class DashboardFloorDetailsState extends Equatable {
  const DashboardFloorDetailsState();

  @override
  List<Object?> get props => [];
}

class DashboardFloorDetailsInitial extends DashboardFloorDetailsState {}

class DashboardFloorDetailsLoading extends DashboardFloorDetailsState {
  final String floorId;

  const DashboardFloorDetailsLoading({required this.floorId});

  @override
  List<Object?> get props => [floorId];
}

class DashboardFloorDetailsSuccess extends DashboardFloorDetailsState {
  final String floorId;
  final DashboardFloorDetails details;

  const DashboardFloorDetailsSuccess({
    required this.floorId,
    required this.details,
  });

  @override
  List<Object?> get props => [floorId, details];
}

class DashboardFloorDetailsFailure extends DashboardFloorDetailsState {
  final String floorId;
  final String message;

  const DashboardFloorDetailsFailure({
    required this.floorId,
    required this.message,
  });

  @override
  List<Object?> get props => [floorId, message];
}

// Bloc
class DashboardFloorDetailsBloc
    extends Bloc<DashboardFloorDetailsEvent, DashboardFloorDetailsState> {
  final GetDashboardFloorDetailsUseCase getDashboardFloorDetailsUseCase;

  DashboardFloorDetailsBloc({
    required this.getDashboardFloorDetailsUseCase,
  }) : super(DashboardFloorDetailsInitial()) {
    on<DashboardFloorDetailsRequested>(_onRequested);
    on<DashboardFloorDetailsReset>(
      (event, emit) => emit(DashboardFloorDetailsInitial()),
    );
  }

  Future<void> _onRequested(
    DashboardFloorDetailsRequested event,
    Emitter<DashboardFloorDetailsState> emit,
  ) async {
    emit(DashboardFloorDetailsLoading(floorId: event.floorId));

    final result = await getDashboardFloorDetailsUseCase(event.floorId);
    result.fold(
      (failure) => emit(
        DashboardFloorDetailsFailure(
          floorId: event.floorId,
          message: _mapFailure(failure),
        ),
      ),
      (response) {
        final details = response.data;
        if (details == null) {
          emit(
            DashboardFloorDetailsFailure(
              floorId: event.floorId,
              message: 'Floor details not found',
            ),
          );
          return;
        }
        emit(
          DashboardFloorDetailsSuccess(
            floorId: event.floorId,
            details: details,
          ),
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
