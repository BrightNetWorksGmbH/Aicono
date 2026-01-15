import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/loxone_connection_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/connect_loxone_usecase.dart';

// Events
abstract class ConnectLoxoneEvent extends Equatable {
  const ConnectLoxoneEvent();

  @override
  List<Object?> get props => [];
}

class ConnectLoxoneSubmitted extends ConnectLoxoneEvent {
  final String buildingId;
  final LoxoneConnectionRequest request;

  const ConnectLoxoneSubmitted({
    required this.buildingId,
    required this.request,
  });

  @override
  List<Object?> get props => [buildingId, request];
}

class ConnectLoxoneReset extends ConnectLoxoneEvent {}

// States
abstract class ConnectLoxoneState extends Equatable {
  const ConnectLoxoneState();

  @override
  List<Object?> get props => [];
}

class ConnectLoxoneInitial extends ConnectLoxoneState {}

class ConnectLoxoneLoading extends ConnectLoxoneState {}

class ConnectLoxoneSuccess extends ConnectLoxoneState {
  final LoxoneConnectionResponse response;

  const ConnectLoxoneSuccess({required this.response});

  @override
  List<Object?> get props => [response];
}

class ConnectLoxoneFailure extends ConnectLoxoneState {
  final String message;

  const ConnectLoxoneFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class ConnectLoxoneBloc extends Bloc<ConnectLoxoneEvent, ConnectLoxoneState> {
  final ConnectLoxoneUseCase connectLoxoneUseCase;

  ConnectLoxoneBloc({required this.connectLoxoneUseCase})
      : super(ConnectLoxoneInitial()) {
    on<ConnectLoxoneSubmitted>(_onConnectLoxoneSubmitted);
    on<ConnectLoxoneReset>(_onConnectLoxoneReset);
  }

  Future<void> _onConnectLoxoneSubmitted(
    ConnectLoxoneSubmitted event,
    Emitter<ConnectLoxoneState> emit,
  ) async {
    emit(ConnectLoxoneLoading());

    final result = await connectLoxoneUseCase(event.buildingId, event.request);

    result.fold(
      (failure) => emit(ConnectLoxoneFailure(
          message: _mapFailureToMessage(failure))),
      (response) => emit(ConnectLoxoneSuccess(response: response)),
    );
  }

  void _onConnectLoxoneReset(
    ConnectLoxoneReset event,
    Emitter<ConnectLoxoneState> emit,
  ) {
    emit(ConnectLoxoneInitial());
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return (failure as ServerFailure).message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

