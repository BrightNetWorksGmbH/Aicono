import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/save_floor_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/save_floor_usecase.dart';

// Events
abstract class SaveFloorEvent extends Equatable {
  const SaveFloorEvent();

  @override
  List<Object?> get props => [];
}

class SaveFloorSubmitted extends SaveFloorEvent {
  final String buildingId;
  final SaveFloorRequest request;

  const SaveFloorSubmitted({
    required this.buildingId,
    required this.request,
  });

  @override
  List<Object?> get props => [buildingId, request];
}

class SaveFloorReset extends SaveFloorEvent {}

// States
abstract class SaveFloorState extends Equatable {
  const SaveFloorState();

  @override
  List<Object?> get props => [];
}

class SaveFloorInitial extends SaveFloorState {}

class SaveFloorLoading extends SaveFloorState {}

class SaveFloorSuccess extends SaveFloorState {
  final SaveFloorResponse response;

  const SaveFloorSuccess({required this.response});

  @override
  List<Object?> get props => [response];
}

class SaveFloorFailure extends SaveFloorState {
  final String message;

  const SaveFloorFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class SaveFloorBloc extends Bloc<SaveFloorEvent, SaveFloorState> {
  final SaveFloorUseCase saveFloorUseCase;

  SaveFloorBloc({required this.saveFloorUseCase}) : super(SaveFloorInitial()) {
    on<SaveFloorSubmitted>(_onSaveFloorSubmitted);
    on<SaveFloorReset>(_onSaveFloorReset);
  }

  Future<void> _onSaveFloorSubmitted(
    SaveFloorSubmitted event,
    Emitter<SaveFloorState> emit,
  ) async {
    emit(SaveFloorLoading());

    final result = await saveFloorUseCase(event.buildingId, event.request);

    result.fold(
      (failure) => emit(SaveFloorFailure(
          message: _mapFailureToMessage(failure))),
      (response) => emit(SaveFloorSuccess(response: response)),
    );
  }

  void _onSaveFloorReset(
    SaveFloorReset event,
    Emitter<SaveFloorState> emit,
  ) {
    emit(SaveFloorInitial());
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

