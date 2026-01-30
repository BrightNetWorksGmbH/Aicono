import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_summary_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_building_reports_usecase.dart';

abstract class BuildingReportsEvent extends Equatable {
  const BuildingReportsEvent();
  @override
  List<Object?> get props => [];
}

class BuildingReportsRequested extends BuildingReportsEvent {
  final String buildingId;
  const BuildingReportsRequested(this.buildingId);
  @override
  List<Object?> get props => [buildingId];
}

class BuildingReportsReset extends BuildingReportsEvent {}

abstract class BuildingReportsState extends Equatable {
  const BuildingReportsState();
  @override
  List<Object?> get props => [];
}

class BuildingReportsInitial extends BuildingReportsState {}

class BuildingReportsLoading extends BuildingReportsState {
  final String buildingId;
  const BuildingReportsLoading(this.buildingId);
  @override
  List<Object?> get props => [buildingId];
}

class BuildingReportsSuccess extends BuildingReportsState {
  final String buildingId;
  final List<ReportSummaryEntity> reports;
  const BuildingReportsSuccess({
    required this.buildingId,
    required this.reports,
  });
  @override
  List<Object?> get props => [buildingId, reports];
}

class BuildingReportsFailure extends BuildingReportsState {
  final String message;
  const BuildingReportsFailure({required this.message});
  @override
  List<Object?> get props => [message];
}

class BuildingReportsBloc
    extends Bloc<BuildingReportsEvent, BuildingReportsState> {
  final GetBuildingReportsUseCase getBuildingReportsUseCase;

  BuildingReportsBloc({required this.getBuildingReportsUseCase})
    : super(BuildingReportsInitial()) {
    on<BuildingReportsRequested>(_onRequested);
    on<BuildingReportsReset>((event, emit) => emit(BuildingReportsInitial()));
  }

  Future<void> _onRequested(
    BuildingReportsRequested event,
    Emitter<BuildingReportsState> emit,
  ) async {
    emit(BuildingReportsLoading(event.buildingId));
    final result = await getBuildingReportsUseCase(event.buildingId);
    result.fold(
      (failure) => emit(BuildingReportsFailure(message: _mapFailure(failure))),
      (response) => emit(
        BuildingReportsSuccess(
          buildingId: event.buildingId,
          reports: response.data,
        ),
      ),
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
