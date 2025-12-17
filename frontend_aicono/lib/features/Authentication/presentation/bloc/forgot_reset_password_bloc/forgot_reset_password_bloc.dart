import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/forgot_reset_password_usecase.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forgot_reset_password_bloc/forgot_reset_password_event.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forgot_reset_password_bloc/forgot_reset_password_state.dart';

class ForgotResetPasswordBloc
    extends Bloc<ForgotResetPasswordEvent, ForgotResetPasswordState> {
  final ForgotResetPasswordUseCase forgotResetPasswordUseCase;

  ForgotResetPasswordBloc({required this.forgotResetPasswordUseCase})
    : super(ForgotResetPasswordInitial()) {
    on<ResetPasswordWithTokenRequested>(_onResetPasswordWithTokenRequested);
  }

  Future<void> _onResetPasswordWithTokenRequested(
    ResetPasswordWithTokenRequested event,
    Emitter<ForgotResetPasswordState> emit,
  ) async {
    emit(ForgotResetPasswordLoading());

    final result = await forgotResetPasswordUseCase(
      token: event.token,
      newPassword: event.newPassword,
      confirmPassword: event.confirmPassword,
    );

    result.fold(
      (failure) => emit(ForgotResetPasswordFailure(failure.message)),
      (message) => emit(ForgotResetPasswordSuccess(message)),
    );
  }
}
