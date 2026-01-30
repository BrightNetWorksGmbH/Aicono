import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_site_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_sites_usecase.dart';

abstract class ReportSitesEvent extends Equatable {
  const ReportSitesEvent();
  @override
  List<Object?> get props => [];
}

class ReportSitesRequested extends ReportSitesEvent {}

class ReportSitesReset extends ReportSitesEvent {}

abstract class ReportSitesState extends Equatable {
  const ReportSitesState();
  @override
  List<Object?> get props => [];
}

class ReportSitesInitial extends ReportSitesState {}

class ReportSitesLoading extends ReportSitesState {}

class ReportSitesSuccess extends ReportSitesState {
  final List<ReportSiteEntity> sites;
  const ReportSitesSuccess({required this.sites});
  @override
  List<Object?> get props => [sites];
}

class ReportSitesFailure extends ReportSitesState {
  final String message;
  const ReportSitesFailure({required this.message});
  @override
  List<Object?> get props => [message];
}

class ReportSitesBloc extends Bloc<ReportSitesEvent, ReportSitesState> {
  final GetReportSitesUseCase getReportSitesUseCase;

  ReportSitesBloc({required this.getReportSitesUseCase})
    : super(ReportSitesInitial()) {
    on<ReportSitesRequested>(_onRequested);
    on<ReportSitesReset>((event, emit) => emit(ReportSitesInitial()));
  }

  Future<void> _onRequested(
    ReportSitesRequested event,
    Emitter<ReportSitesState> emit,
  ) async {
    emit(ReportSitesLoading());
    final result = await getReportSitesUseCase();
    result.fold(
      (failure) => emit(ReportSitesFailure(message: _mapFailure(failure))),
      (response) => emit(ReportSitesSuccess(sites: response.data)),
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
