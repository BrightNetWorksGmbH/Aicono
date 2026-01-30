import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_sites_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_sites_usecase.dart';

// Events
abstract class DashboardSitesEvent extends Equatable {
  const DashboardSitesEvent();

  @override
  List<Object?> get props => [];
}

class DashboardSitesRequested extends DashboardSitesEvent {}

class DashboardSitesReset extends DashboardSitesEvent {}

// States
abstract class DashboardSitesState extends Equatable {
  const DashboardSitesState();

  @override
  List<Object?> get props => [];
}

class DashboardSitesInitial extends DashboardSitesState {}

class DashboardSitesLoading extends DashboardSitesState {}

class DashboardSitesSuccess extends DashboardSitesState {
  final List<DashboardSiteSummary> sites;

  const DashboardSitesSuccess({required this.sites});

  @override
  List<Object?> get props => [sites];
}

class DashboardSitesFailure extends DashboardSitesState {
  final String message;

  const DashboardSitesFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// Bloc
class DashboardSitesBloc
    extends Bloc<DashboardSitesEvent, DashboardSitesState> {
  final GetDashboardSitesUseCase getDashboardSitesUseCase;

  DashboardSitesBloc({required this.getDashboardSitesUseCase})
    : super(DashboardSitesInitial()) {
    on<DashboardSitesRequested>(_onRequested);
    on<DashboardSitesReset>((event, emit) => emit(DashboardSitesInitial()));
  }

  Future<void> _onRequested(
    DashboardSitesRequested event,
    Emitter<DashboardSitesState> emit,
  ) async {
    emit(DashboardSitesLoading());

    final result = await getDashboardSitesUseCase();
    result.fold(
      (failure) => emit(DashboardSitesFailure(message: _mapFailure(failure))),
      (response) => emit(DashboardSitesSuccess(sites: response.data)),
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
