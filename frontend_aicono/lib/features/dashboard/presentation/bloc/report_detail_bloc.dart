import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_detail_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_detail_usecase.dart';

abstract class ReportDetailEvent extends Equatable {
  const ReportDetailEvent();
  @override
  List<Object?> get props => [];
}

class ReportDetailRequested extends ReportDetailEvent {
  final String reportId;
  const ReportDetailRequested(this.reportId);
  @override
  List<Object?> get props => [reportId];
}

class ReportDetailReset extends ReportDetailEvent {}

abstract class ReportDetailState extends Equatable {
  const ReportDetailState();
  @override
  List<Object?> get props => [];
}

class ReportDetailInitial extends ReportDetailState {}

class ReportDetailLoading extends ReportDetailState {
  final String reportId;
  const ReportDetailLoading(this.reportId);
  @override
  List<Object?> get props => [reportId];
}

class ReportDetailSuccess extends ReportDetailState {
  final ReportDetailEntity detail;
  const ReportDetailSuccess({required this.detail});
  @override
  List<Object?> get props => [detail];
}

class ReportDetailFailure extends ReportDetailState {
  final String message;
  const ReportDetailFailure({required this.message});
  @override
  List<Object?> get props => [message];
}

class ReportDetailBloc extends Bloc<ReportDetailEvent, ReportDetailState> {
  final GetReportDetailUseCase getReportDetailUseCase;

  ReportDetailBloc({required this.getReportDetailUseCase})
    : super(ReportDetailInitial()) {
    on<ReportDetailRequested>(_onRequested);
    on<ReportDetailReset>((event, emit) => emit(ReportDetailInitial()));
  }

  Future<void> _onRequested(
    ReportDetailRequested event,
    Emitter<ReportDetailState> emit,
  ) async {
    emit(ReportDetailLoading(event.reportId));
    final result = await getReportDetailUseCase(event.reportId);
    result.fold(
      (failure) => emit(ReportDetailFailure(message: _mapFailure(failure))),
      (response) {
        if (response.data != null) {
          emit(ReportDetailSuccess(detail: response.data!));
        } else {
          emit(
            const ReportDetailFailure(message: 'Report detail not available.'),
          );
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
