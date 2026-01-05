import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/send_brytesight_invitation_usecase.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_invitation_bloc/brytesight_invitation_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_invitation_bloc/brytesight_invitation_state.dart';

class BryteSightInvitationBloc
    extends Bloc<BryteSightInvitationEvent, BryteSightInvitationState> {
  final SendBryteSightInvitationUseCase sendBryteSightInvitationUseCase;

  BryteSightInvitationBloc({required this.sendBryteSightInvitationUseCase})
    : super(BryteSightInvitationInitial()) {
    on<SendBryteSightInvitationRequested>(_onSendBryteSightInvitationRequested);
  }

  Future<void> _onSendBryteSightInvitationRequested(
    SendBryteSightInvitationRequested event,
    Emitter<BryteSightInvitationState> emit,
  ) async {
    emit(BryteSightInvitationLoading());

    final result = await sendBryteSightInvitationUseCase(
      event.verseId,
      event.recipientEmail,
    );

    result.fold(
      (failure) => emit(BryteSightInvitationFailure(failure.message)),
      (_) => emit(
        const BryteSightInvitationSuccess('Invitation sent successfully'),
      ),
    );
  }
}
