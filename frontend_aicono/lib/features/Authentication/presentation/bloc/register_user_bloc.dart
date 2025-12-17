import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/register_user_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/register_user_usecase.dart';

// Events
abstract class RegisterUserEvent extends Equatable {
  const RegisterUserEvent();

  @override
  List<Object?> get props => [];
}

class RegisterUserSubmitted extends RegisterUserEvent {
  final RegisterUserRequest request;

  const RegisterUserSubmitted(this.request);

  @override
  List<Object?> get props => [request];
}

// States
abstract class RegisterUserState extends Equatable {
  const RegisterUserState();

  @override
  List<Object?> get props => [];
}

class RegisterUserInitial extends RegisterUserState {}

class RegisterUserLoading extends RegisterUserState {}

class RegisterUserSuccess extends RegisterUserState {
  final RegisterUserResponse response;

  const RegisterUserSuccess({required this.response});

  @override
  List<Object?> get props => [response];
}

class RegisterUserFailure extends RegisterUserState {
  final String message;

  const RegisterUserFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class RegisterUserBloc extends Bloc<RegisterUserEvent, RegisterUserState> {
  final RegisterUserUseCase registerUserUseCase;

  RegisterUserBloc({required this.registerUserUseCase})
    : super(RegisterUserInitial()) {
    on<RegisterUserSubmitted>(_onRegisterUserSubmitted);
  }

  Future<void> _onRegisterUserSubmitted(
    RegisterUserSubmitted event,
    Emitter<RegisterUserState> emit,
  ) async {
    emit(RegisterUserLoading());

    final result = await registerUserUseCase(event.request);

    result.fold(
      (failure) =>
          emit(RegisterUserFailure(message: _mapFailureToMessage(failure))),
      (response) => emit(RegisterUserSuccess(response: response)),
    );
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return failure.message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      case CacheFailure:
        return 'Cache error occurred.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
