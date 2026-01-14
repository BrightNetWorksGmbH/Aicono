import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/create_buildings_usecase.dart';

// Events
abstract class CreateBuildingsEvent extends Equatable {
  const CreateBuildingsEvent();

  @override
  List<Object?> get props => [];
}

class CreateBuildingsSubmitted extends CreateBuildingsEvent {
  final String siteId;
  final CreateBuildingsRequest request;

  const CreateBuildingsSubmitted({
    required this.siteId,
    required this.request,
  });

  @override
  List<Object?> get props => [siteId, request];
}

class CreateBuildingsReset extends CreateBuildingsEvent {}

// States
abstract class CreateBuildingsState extends Equatable {
  const CreateBuildingsState();

  @override
  List<Object?> get props => [];
}

class CreateBuildingsInitial extends CreateBuildingsState {}

class CreateBuildingsLoading extends CreateBuildingsState {}

class CreateBuildingsSuccess extends CreateBuildingsState {
  final CreateBuildingsResponse response;

  const CreateBuildingsSuccess({required this.response});

  @override
  List<Object?> get props => [response];
}

class CreateBuildingsFailure extends CreateBuildingsState {
  final String message;

  const CreateBuildingsFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class CreateBuildingsBloc extends Bloc<CreateBuildingsEvent, CreateBuildingsState> {
  final CreateBuildingsUseCase createBuildingsUseCase;

  CreateBuildingsBloc({required this.createBuildingsUseCase})
      : super(CreateBuildingsInitial()) {
    on<CreateBuildingsSubmitted>(_onCreateBuildingsSubmitted);
    on<CreateBuildingsReset>(_onCreateBuildingsReset);
  }

  Future<void> _onCreateBuildingsSubmitted(
    CreateBuildingsSubmitted event,
    Emitter<CreateBuildingsState> emit,
  ) async {
    emit(CreateBuildingsLoading());

    final result = await createBuildingsUseCase(event.siteId, event.request);

    result.fold(
      (failure) => emit(CreateBuildingsFailure(message: _mapFailureToMessage(failure))),
      (response) => emit(CreateBuildingsSuccess(response: response)),
    );
  }

  void _onCreateBuildingsReset(
    CreateBuildingsReset event,
    Emitter<CreateBuildingsState> emit,
  ) {
    emit(CreateBuildingsInitial());
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return (failure as ServerFailure).message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      case CacheFailure:
        return 'Cache error occurred.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
