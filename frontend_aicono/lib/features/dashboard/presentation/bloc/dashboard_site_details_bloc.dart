import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_details_filter.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/dashboard_site_details_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_dashboard_site_details_usecase.dart';

// Events
abstract class DashboardSiteDetailsEvent extends Equatable {
  const DashboardSiteDetailsEvent();

  @override
  List<Object?> get props => [];
}

class DashboardSiteDetailsRequested extends DashboardSiteDetailsEvent {
  final String siteId;
  final DashboardDetailsFilter? filter;

  const DashboardSiteDetailsRequested({
    required this.siteId,
    this.filter,
  });

  @override
  List<Object?> get props => [siteId, filter];
}

class DashboardSiteDetailsReset extends DashboardSiteDetailsEvent {}

// States
abstract class DashboardSiteDetailsState extends Equatable {
  const DashboardSiteDetailsState();

  @override
  List<Object?> get props => [];
}

class DashboardSiteDetailsInitial extends DashboardSiteDetailsState {}

class DashboardSiteDetailsLoading extends DashboardSiteDetailsState {
  final String siteId;

  const DashboardSiteDetailsLoading({required this.siteId});

  @override
  List<Object?> get props => [siteId];
}

class DashboardSiteDetailsSuccess extends DashboardSiteDetailsState {
  final String siteId;
  final DashboardSiteDetails details;

  const DashboardSiteDetailsSuccess({required this.siteId, required this.details});

  @override
  List<Object?> get props => [siteId, details];
}

class DashboardSiteDetailsFailure extends DashboardSiteDetailsState {
  final String siteId;
  final String message;

  const DashboardSiteDetailsFailure({required this.siteId, required this.message});

  @override
  List<Object?> get props => [siteId, message];
}

// Bloc
class DashboardSiteDetailsBloc
    extends Bloc<DashboardSiteDetailsEvent, DashboardSiteDetailsState> {
  final GetDashboardSiteDetailsUseCase getDashboardSiteDetailsUseCase;

  DashboardSiteDetailsBloc({required this.getDashboardSiteDetailsUseCase})
      : super(DashboardSiteDetailsInitial()) {
    on<DashboardSiteDetailsRequested>(_onRequested);
    on<DashboardSiteDetailsReset>((event, emit) => emit(DashboardSiteDetailsInitial()));
  }

  Future<void> _onRequested(
    DashboardSiteDetailsRequested event,
    Emitter<DashboardSiteDetailsState> emit,
  ) async {
    emit(DashboardSiteDetailsLoading(siteId: event.siteId));

    final result = await getDashboardSiteDetailsUseCase(
      event.siteId,
      filter: event.filter,
    );
    result.fold(
      (failure) => emit(
        DashboardSiteDetailsFailure(
          siteId: event.siteId,
          message: _mapFailure(failure),
        ),
      ),
      (response) {
        final details = response.data;
        if (details == null) {
          emit(
            DashboardSiteDetailsFailure(
              siteId: event.siteId,
              message: 'Site details not found',
            ),
          );
          return;
        }
        emit(
          DashboardSiteDetailsSuccess(siteId: event.siteId, details: details),
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

