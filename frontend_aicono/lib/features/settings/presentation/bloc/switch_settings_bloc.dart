import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/settings/domain/entities/switch_details_entity.dart';
import 'package:frontend_aicono/features/settings/domain/entities/update_switch_request.dart';
import 'package:frontend_aicono/features/settings/domain/usecases/get_switch_by_id_usecase.dart';
import 'package:frontend_aicono/features/settings/domain/usecases/update_switch_usecase.dart';

// Events
abstract class SwitchSettingsEvent extends Equatable {
  const SwitchSettingsEvent();

  @override
  List<Object?> get props => [];
}

class SwitchDetailsRequested extends SwitchSettingsEvent {
  final String switchId;

  const SwitchDetailsRequested({required this.switchId});

  @override
  List<Object?> get props => [switchId];
}

class SwitchDetailsUpdateSubmitted extends SwitchSettingsEvent {
  final String switchId;
  final UpdateSwitchRequest request;

  const SwitchDetailsUpdateSubmitted({
    required this.switchId,
    required this.request,
  });

  @override
  List<Object?> get props => [switchId, request];
}

class SwitchSettingsReset extends SwitchSettingsEvent {}

// States
abstract class SwitchSettingsState extends Equatable {
  const SwitchSettingsState();

  @override
  List<Object?> get props => [];
}

class SwitchSettingsInitial extends SwitchSettingsState {}

class SwitchSettingsLoading extends SwitchSettingsState {}

class SwitchSettingsLoaded extends SwitchSettingsState {
  final SwitchDetailsEntity switchDetails;

  const SwitchSettingsLoaded({required this.switchDetails});

  @override
  List<Object?> get props => [switchDetails];
}

class SwitchSettingsUpdating extends SwitchSettingsState {
  final SwitchDetailsEntity switchDetails;

  const SwitchSettingsUpdating({required this.switchDetails});

  @override
  List<Object?> get props => [switchDetails];
}

class SwitchSettingsUpdateSuccess extends SwitchSettingsState {
  final SwitchDetailsEntity switchDetails;

  const SwitchSettingsUpdateSuccess({required this.switchDetails});

  @override
  List<Object?> get props => [switchDetails];
}

class SwitchSettingsFailure extends SwitchSettingsState {
  final String message;

  const SwitchSettingsFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class SwitchSettingsBloc extends Bloc<SwitchSettingsEvent, SwitchSettingsState> {
  final GetSwitchByIdUseCase getSwitchByIdUseCase;
  final UpdateSwitchUseCase updateSwitchUseCase;

  SwitchSettingsBloc({
    required this.getSwitchByIdUseCase,
    required this.updateSwitchUseCase,
  }) : super(SwitchSettingsInitial()) {
    on<SwitchDetailsRequested>(_onSwitchDetailsRequested);
    on<SwitchDetailsUpdateSubmitted>(_onSwitchDetailsUpdateSubmitted);
    on<SwitchSettingsReset>(_onSwitchSettingsReset);
  }

  Future<void> _onSwitchDetailsRequested(
    SwitchDetailsRequested event,
    Emitter<SwitchSettingsState> emit,
  ) async {
    emit(SwitchSettingsLoading());

    final result = await getSwitchByIdUseCase(event.switchId);

    result.fold(
      (failure) => emit(
        SwitchSettingsFailure(message: _mapFailureToMessage(failure)),
      ),
      (switchDetails) => emit(SwitchSettingsLoaded(switchDetails: switchDetails)),
    );
  }

  Future<void> _onSwitchDetailsUpdateSubmitted(
    SwitchDetailsUpdateSubmitted event,
    Emitter<SwitchSettingsState> emit,
  ) async {
    final currentSwitch = state is SwitchSettingsLoaded
        ? (state as SwitchSettingsLoaded).switchDetails
        : null;
    if (currentSwitch != null) {
      emit(SwitchSettingsUpdating(switchDetails: currentSwitch));
    } else {
      emit(SwitchSettingsLoading());
    }

    final result = await updateSwitchUseCase(event.switchId, event.request);

    result.fold(
      (failure) => emit(
        SwitchSettingsFailure(message: _mapFailureToMessage(failure)),
      ),
      (switchDetails) => emit(
        SwitchSettingsUpdateSuccess(switchDetails: switchDetails),
      ),
    );
  }

  void _onSwitchSettingsReset(
    SwitchSettingsReset event,
    Emitter<SwitchSettingsState> emit,
  ) {
    emit(SwitchSettingsInitial());
  }

  String _mapFailureToMessage(Failure failure) {
    return switch (failure) {
      ServerFailure() => failure.message,
      NetworkFailure() => 'Network error. Please check your connection.',
      CacheFailure() => 'Cache error occurred.',
      _ => 'An unexpected error occurred.',
    };
  }
}
