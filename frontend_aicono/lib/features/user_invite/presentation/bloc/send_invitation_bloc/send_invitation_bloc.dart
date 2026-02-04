import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/user_invite/domain/usecases/send_invitation_usecase.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/send_invitation_bloc/send_invitation_event.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/send_invitation_bloc/send_invitation_state.dart';

class SendInvitationBloc
    extends Bloc<SendInvitationEvent, SendInvitationState> {
  final SendInvitationUseCase sendInvitationUseCase;

  SendInvitationBloc({required this.sendInvitationUseCase})
    : super(SendInvitationInitial()) {
    on<SendInvitationSubmitted>(_onSubmitted);
    on<SendInvitationReset>((event, emit) => emit(SendInvitationInitial()));
  }

  Future<void> _onSubmitted(
    SendInvitationSubmitted event,
    Emitter<SendInvitationState> emit,
  ) async {
    emit(SendInvitationLoading());

    final result = await sendInvitationUseCase(event.request);
    result.fold(
      (failure) => emit(SendInvitationFailure(message: _mapFailure(failure))),
      (_) => emit(SendInvitationSuccess()),
    );
  }

  String _mapFailure(Failure failure) {
    if (failure is ServerFailure) return failure.message;
    if (failure is NetworkFailure) {
      return 'invite_user.network_error'.tr();
    }
    if (failure is CacheFailure) return 'invite_user.cache_error'.tr();
    return 'invite_user.unexpected_error'.tr();
  }
}
