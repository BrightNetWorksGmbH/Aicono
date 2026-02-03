import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/dashboard/domain/entities/trigger_report_entity.dart';
import 'package:frontend_aicono/features/dashboard/domain/usecases/trigger_report_usecase.dart';

abstract class TriggerReportEvent extends Equatable {
  const TriggerReportEvent();
  @override
  List<Object?> get props => [];
}

class TriggerReportRequested extends TriggerReportEvent {
  final String interval;
  const TriggerReportRequested(this.interval);
  @override
  List<Object?> get props => [interval];
}

abstract class TriggerReportState extends Equatable {
  const TriggerReportState();
  @override
  List<Object?> get props => [];
}

class TriggerReportInitial extends TriggerReportState {
  const TriggerReportInitial();
}

class TriggerReportLoading extends TriggerReportState {
  const TriggerReportLoading();
  @override
  List<Object?> get props => [];
}

class TriggerReportSuccess extends TriggerReportState {
  final TriggerReportResponse response;
  const TriggerReportSuccess({required this.response});
  @override
  List<Object?> get props => [response];
}

class TriggerReportFailure extends TriggerReportState {
  final String message;
  const TriggerReportFailure({required this.message});
  @override
  List<Object?> get props => [message];
}

class TriggerReportBloc extends Bloc<TriggerReportEvent, TriggerReportState> {
  final TriggerReportUseCase triggerReportUseCase;

  TriggerReportBloc({required this.triggerReportUseCase})
    : super(const TriggerReportInitial()) {
    on<TriggerReportRequested>(_onRequested);
  }

  Future<void> _onRequested(
    TriggerReportRequested event,
    Emitter<TriggerReportState> emit,
  ) async {
    emit(const TriggerReportLoading());
    final result = await triggerReportUseCase(event.interval);
    result.fold(
      (failure) => emit(TriggerReportFailure(message: _mapFailure(failure))),
      (response) {
        if (response.success) {
          emit(TriggerReportSuccess(response: response));
        } else {
          emit(
            TriggerReportFailure(
              message: response.message.isNotEmpty
                  ? response.message
                  : 'Failed to trigger report.',
            ),
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
