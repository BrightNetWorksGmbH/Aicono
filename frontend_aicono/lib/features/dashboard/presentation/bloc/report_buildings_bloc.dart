import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_building_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_buildings_usecase.dart';

abstract class ReportBuildingsEvent extends Equatable {
  const ReportBuildingsEvent();
  @override
  List<Object?> get props => [];
}

class ReportBuildingsRequested extends ReportBuildingsEvent {
  final String siteId;
  const ReportBuildingsRequested(this.siteId);
  @override
  List<Object?> get props => [siteId];
}

class ReportBuildingsReset extends ReportBuildingsEvent {}

abstract class ReportBuildingsState extends Equatable {
  const ReportBuildingsState();
  @override
  List<Object?> get props => [];
}

class ReportBuildingsInitial extends ReportBuildingsState {}

class ReportBuildingsLoading extends ReportBuildingsState {
  final String siteId;
  const ReportBuildingsLoading(this.siteId);
  @override
  List<Object?> get props => [siteId];
}

class ReportBuildingsSuccess extends ReportBuildingsState {
  final String siteId;
  final List<ReportBuildingEntity> buildings;
  const ReportBuildingsSuccess({required this.siteId, required this.buildings});
  @override
  List<Object?> get props => [siteId, buildings];
}

class ReportBuildingsFailure extends ReportBuildingsState {
  final String message;
  const ReportBuildingsFailure({required this.message});
  @override
  List<Object?> get props => [message];
}

class ReportBuildingsBloc
    extends Bloc<ReportBuildingsEvent, ReportBuildingsState> {
  final GetReportBuildingsUseCase getReportBuildingsUseCase;

  ReportBuildingsBloc({required this.getReportBuildingsUseCase})
    : super(ReportBuildingsInitial()) {
    on<ReportBuildingsRequested>(_onRequested);
    on<ReportBuildingsReset>((event, emit) => emit(ReportBuildingsInitial()));
  }

  Future<void> _onRequested(
    ReportBuildingsRequested event,
    Emitter<ReportBuildingsState> emit,
  ) async {
    emit(ReportBuildingsLoading(event.siteId));
    final result = await getReportBuildingsUseCase(event.siteId);
    result.fold(
      (failure) => emit(ReportBuildingsFailure(message: _mapFailure(failure))),
      (response) => emit(
        ReportBuildingsSuccess(siteId: event.siteId, buildings: response.data),
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
