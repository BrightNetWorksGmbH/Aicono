import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/settings/domain/usecases/change_password_usecase.dart';

// Events
abstract class ChangePasswordEvent extends Equatable {
  const ChangePasswordEvent();

  @override
  List<Object?> get props => [];
}

class ChangePasswordSubmitted extends ChangePasswordEvent {
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;

  const ChangePasswordSubmitted({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword, confirmPassword];
}

// States
abstract class ChangePasswordState extends Equatable {
  const ChangePasswordState();

  @override
  List<Object?> get props => [];
}

class ChangePasswordInitial extends ChangePasswordState {}

class ChangePasswordLoading extends ChangePasswordState {}

class ChangePasswordSuccess extends ChangePasswordState {}

class ChangePasswordFailure extends ChangePasswordState {
  final String message;

  const ChangePasswordFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class ChangePasswordBloc
    extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  final ChangePasswordUseCase changePasswordUseCase;

  ChangePasswordBloc({
    required this.changePasswordUseCase,
  }) : super(ChangePasswordInitial()) {
    on<ChangePasswordSubmitted>(_onChangePasswordSubmitted);
  }

  Future<void> _onChangePasswordSubmitted(
    ChangePasswordSubmitted event,
    Emitter<ChangePasswordState> emit,
  ) async {
    emit(ChangePasswordLoading());

    final result = await changePasswordUseCase(
      event.currentPassword,
      event.newPassword,
      event.confirmPassword,
    );

    result.fold(
      (failure) => emit(
        ChangePasswordFailure(message: _mapFailureToMessage(failure)),
      ),
      (_) => emit(ChangePasswordSuccess()),
    );
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
