import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/report_token_info_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/get_report_token_info_usecase.dart';

abstract class ReportTokenInfoEvent extends Equatable {
  const ReportTokenInfoEvent();
  @override
  List<Object?> get props => [];
}

class ReportTokenInfoRequested extends ReportTokenInfoEvent {
  final String token;
  const ReportTokenInfoRequested(this.token);
  @override
  List<Object?> get props => [token];
}

class ReportTokenInfoReset extends ReportTokenInfoEvent {}

abstract class ReportTokenInfoState extends Equatable {
  const ReportTokenInfoState();
  @override
  List<Object?> get props => [];
}

class ReportTokenInfoInitial extends ReportTokenInfoState {}

class ReportTokenInfoLoading extends ReportTokenInfoState {
  const ReportTokenInfoLoading();
  @override
  List<Object?> get props => [];
}

class ReportTokenInfoSuccess extends ReportTokenInfoState {
  final ReportTokenInfoEntity info;
  const ReportTokenInfoSuccess({required this.info});
  @override
  List<Object?> get props => [info];
}

class ReportTokenInfoFailure extends ReportTokenInfoState {
  final String message;
  const ReportTokenInfoFailure({required this.message});
  @override
  List<Object?> get props => [message];
}

class ReportTokenInfoBloc
    extends Bloc<ReportTokenInfoEvent, ReportTokenInfoState> {
  final GetReportTokenInfoUseCase getReportTokenInfoUseCase;

  ReportTokenInfoBloc({required this.getReportTokenInfoUseCase})
    : super(ReportTokenInfoInitial()) {
    on<ReportTokenInfoRequested>(_onRequested);
    on<ReportTokenInfoReset>((event, emit) => emit(ReportTokenInfoInitial()));
  }

  Future<void> _onRequested(
    ReportTokenInfoRequested event,
    Emitter<ReportTokenInfoState> emit,
  ) async {
    emit(const ReportTokenInfoLoading());
    final result = await getReportTokenInfoUseCase(event.token);
    result.fold(
      (failure) => emit(ReportTokenInfoFailure(message: _mapFailure(failure))),
      (response) {
        if (response.data != null) {
          emit(ReportTokenInfoSuccess(info: response.data!));
        } else {
          emit(
            const ReportTokenInfoFailure(message: 'Report info not available.'),
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
