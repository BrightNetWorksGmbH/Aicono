import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/send_reset_link_usecase.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forget_password_bloc/forgot_password_event.dart';
import 'package:frontend_aicono/features/Authentication/presentation/bloc/forget_password_bloc/forgot_password_state.dart';

class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  final SendResetLinkUseCase sendResetLinkUseCase;

  ForgotPasswordBloc({required this.sendResetLinkUseCase})
    : super(ForgotPasswordInitial()) {
    on<SendResetLinkRequested>(_onSendResetLinkRequested);
  }

  Future<void> _onSendResetLinkRequested(
    SendResetLinkRequested event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(ForgotPasswordLoading());

    final result = await sendResetLinkUseCase(event.email);

    result.fold(
      (failure) => emit(ForgotPasswordFailure(failure.message)),
      (message) => emit(ForgotPasswordSuccess(message)),
    );
  }
}
