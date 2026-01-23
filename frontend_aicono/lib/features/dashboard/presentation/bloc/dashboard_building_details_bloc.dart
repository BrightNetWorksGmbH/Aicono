import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_building_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_building_details_usecase.dart';

// Events
abstract class DashboardBuildingDetailsEvent extends Equatable {
  const DashboardBuildingDetailsEvent();

  @override
  List<Object?> get props => [];
}

class DashboardBuildingDetailsRequested extends DashboardBuildingDetailsEvent {
  final String buildingId;

  const DashboardBuildingDetailsRequested({required this.buildingId});

  @override
  List<Object?> get props => [buildingId];
}

class DashboardBuildingDetailsReset extends DashboardBuildingDetailsEvent {}

// States
abstract class DashboardBuildingDetailsState extends Equatable {
  const DashboardBuildingDetailsState();

  @override
  List<Object?> get props => [];
}

class DashboardBuildingDetailsInitial extends DashboardBuildingDetailsState {}

class DashboardBuildingDetailsLoading extends DashboardBuildingDetailsState {
  final String buildingId;

  const DashboardBuildingDetailsLoading({required this.buildingId});

  @override
  List<Object?> get props => [buildingId];
}

class DashboardBuildingDetailsSuccess extends DashboardBuildingDetailsState {
  final String buildingId;
  final DashboardBuildingDetails details;

  const DashboardBuildingDetailsSuccess({
    required this.buildingId,
    required this.details,
  });

  @override
  List<Object?> get props => [buildingId, details];
}

class DashboardBuildingDetailsFailure extends DashboardBuildingDetailsState {
  final String buildingId;
  final String message;

  const DashboardBuildingDetailsFailure({
    required this.buildingId,
    required this.message,
  });

  @override
  List<Object?> get props => [buildingId, message];
}

// Bloc
class DashboardBuildingDetailsBloc
    extends Bloc<DashboardBuildingDetailsEvent, DashboardBuildingDetailsState> {
  final GetDashboardBuildingDetailsUseCase getDashboardBuildingDetailsUseCase;

  DashboardBuildingDetailsBloc({
    required this.getDashboardBuildingDetailsUseCase,
  }) : super(DashboardBuildingDetailsInitial()) {
    on<DashboardBuildingDetailsRequested>(_onRequested);
    on<DashboardBuildingDetailsReset>(
      (event, emit) => emit(DashboardBuildingDetailsInitial()),
    );
  }

  Future<void> _onRequested(
    DashboardBuildingDetailsRequested event,
    Emitter<DashboardBuildingDetailsState> emit,
  ) async {
    emit(DashboardBuildingDetailsLoading(buildingId: event.buildingId));

    final result = await getDashboardBuildingDetailsUseCase(event.buildingId);
    result.fold(
      (failure) => emit(
        DashboardBuildingDetailsFailure(
          buildingId: event.buildingId,
          message: _mapFailure(failure),
        ),
      ),
      (response) {
        final details = response.data;
        if (details == null) {
          emit(
            DashboardBuildingDetailsFailure(
              buildingId: event.buildingId,
              message: 'Building details not found',
            ),
          );
          return;
        }
        emit(
          DashboardBuildingDetailsSuccess(
            buildingId: event.buildingId,
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
