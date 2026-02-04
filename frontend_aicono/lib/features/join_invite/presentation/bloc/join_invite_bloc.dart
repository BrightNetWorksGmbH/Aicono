import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/join_invite/domain/usecases/join_switch_usecase.dart';

// Events
abstract class JoinInviteEvent extends Equatable {
  const JoinInviteEvent();

  @override
  List<Object?> get props => [];
}

class JoinSwitchRequested extends JoinInviteEvent {
  final InvitationEntity invitation;

  const JoinSwitchRequested({required this.invitation});

  @override
  List<Object?> get props => [invitation];
}

// States
abstract class JoinInviteState extends Equatable {
  const JoinInviteState();

  @override
  List<Object?> get props => [];
}

class JoinInviteInitial extends JoinInviteState {}

class JoinInviteLoading extends JoinInviteState {}

class JoinInviteSuccess extends JoinInviteState {}

class JoinInviteFailure extends JoinInviteState {
  final String message;

  const JoinInviteFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class JoinInviteBloc extends Bloc<JoinInviteEvent, JoinInviteState> {
  final JoinSwitchUseCase joinSwitchUseCase;

  JoinInviteBloc({required this.joinSwitchUseCase})
    : super(JoinInviteInitial()) {
    on<JoinSwitchRequested>(_onJoinRequested);
  }

  Future<void> _onJoinRequested(
    JoinSwitchRequested event,
    Emitter<JoinInviteState> emit,
  ) async {
    emit(JoinInviteLoading());

    final result = await joinSwitchUseCase(event.invitation.verseId);
    result.fold(
      (failure) => emit(JoinInviteFailure(message: _mapFailure(failure))),
      (_) => emit(JoinInviteSuccess()),
    );
  }

  String _mapFailure(Failure failure) {
    if (failure is ServerFailure) return failure.message;
    if (failure is NetworkFailure) {
      return 'Network error. Please check your connection.';
    }
    if (failure is CacheFailure) return 'Cache error occurred.';
    return 'An unexpected error occurred.';
  }
}
