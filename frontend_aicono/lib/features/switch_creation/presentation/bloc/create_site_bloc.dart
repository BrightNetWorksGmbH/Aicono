import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/create_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/create_site_usecase.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/update_site_usecase.dart';

// Events
abstract class CreateSiteEvent extends Equatable {
  const CreateSiteEvent();

  @override
  List<Object?> get props => [];
}

class CreateSiteSubmitted extends CreateSiteEvent {
  final String switchId;
  final CreateSiteRequest request;

  const CreateSiteSubmitted({
    required this.switchId,
    required this.request,
  });

  @override
  List<Object?> get props => [switchId, request];
}

class UpdateSiteSubmitted extends CreateSiteEvent {
  final String siteId;
  final CreateSiteRequest request;

  const UpdateSiteSubmitted({
    required this.siteId,
    required this.request,
  });

  @override
  List<Object?> get props => [siteId, request];
}

class CreateSiteReset extends CreateSiteEvent {}

// States
abstract class CreateSiteState extends Equatable {
  const CreateSiteState();

  @override
  List<Object?> get props => [];
}

class CreateSiteInitial extends CreateSiteState {}

class CreateSiteLoading extends CreateSiteState {}

class CreateSiteSuccess extends CreateSiteState {
  final CreateSiteResponse response;

  const CreateSiteSuccess({required this.response});

  @override
  List<Object?> get props => [response];
}

class CreateSiteFailure extends CreateSiteState {
  final String message;

  const CreateSiteFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class CreateSiteBloc extends Bloc<CreateSiteEvent, CreateSiteState> {
  final CreateSiteUseCase createSiteUseCase;
  final UpdateSiteUseCase updateSiteUseCase;

  CreateSiteBloc({
    required this.createSiteUseCase,
    required this.updateSiteUseCase,
  }) : super(CreateSiteInitial()) {
    on<CreateSiteSubmitted>(_onCreateSiteSubmitted);
    on<UpdateSiteSubmitted>(_onUpdateSiteSubmitted);
    on<CreateSiteReset>(_onCreateSiteReset);
  }

  Future<void> _onCreateSiteSubmitted(
    CreateSiteSubmitted event,
    Emitter<CreateSiteState> emit,
  ) async {
    emit(CreateSiteLoading());

    final result = await createSiteUseCase(event.switchId, event.request);

    result.fold(
      (failure) => emit(CreateSiteFailure(message: _mapFailureToMessage(failure))),
      (response) => emit(CreateSiteSuccess(response: response)),
    );
  }

  Future<void> _onUpdateSiteSubmitted(
    UpdateSiteSubmitted event,
    Emitter<CreateSiteState> emit,
  ) async {
    emit(CreateSiteLoading());

    final result = await updateSiteUseCase(event.siteId, event.request);

    result.fold(
      (failure) => emit(CreateSiteFailure(message: _mapFailureToMessage(failure))),
      (response) => emit(CreateSiteSuccess(response: response)),
    );
  }

  void _onCreateSiteReset(
    CreateSiteReset event,
    Emitter<CreateSiteState> emit,
  ) {
    emit(CreateSiteInitial());
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
