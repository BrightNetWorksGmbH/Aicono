import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_view_by_token_usecase.dart';

abstract class ReportViewEvent extends Equatable {
  const ReportViewEvent();
  @override
  List<Object?> get props => [];
}

class ReportViewRequested extends ReportViewEvent {
  final String token;
  const ReportViewRequested(this.token);
  @override
  List<Object?> get props => [token];
}

class ReportViewReset extends ReportViewEvent {}

abstract class ReportViewState extends Equatable {
  const ReportViewState();
  @override
  List<Object?> get props => [];
}

class ReportViewInitial extends ReportViewState {}

class ReportViewLoading extends ReportViewState {
  const ReportViewLoading();
  @override
  List<Object?> get props => [];
}

class ReportViewSuccess extends ReportViewState {
  final ReportDetailEntity report;
  const ReportViewSuccess({required this.report});
  @override
  List<Object?> get props => [report];
}

class ReportViewFailure extends ReportViewState {
  final String message;
  const ReportViewFailure({required this.message});
  @override
  List<Object?> get props => [message];
}

class ReportViewBloc extends Bloc<ReportViewEvent, ReportViewState> {
  final GetReportViewByTokenUseCase getReportViewByTokenUseCase;

  ReportViewBloc({required this.getReportViewByTokenUseCase})
    : super(ReportViewInitial()) {
    on<ReportViewRequested>(_onRequested);
    on<ReportViewReset>((event, emit) => emit(ReportViewInitial()));
  }

  Future<void> _onRequested(
    ReportViewRequested event,
    Emitter<ReportViewState> emit,
  ) async {
    emit(const ReportViewLoading());
    final result = await getReportViewByTokenUseCase(event.token);
    result.fold(
      (failure) => emit(ReportViewFailure(message: _mapFailure(failure))),
      (response) {
        if (response.data != null) {
          emit(ReportViewSuccess(report: response.data!));
        } else {
          emit(const ReportViewFailure(message: 'Report data not available.'));
        }
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
