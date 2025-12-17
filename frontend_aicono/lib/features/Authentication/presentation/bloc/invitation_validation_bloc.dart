import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';
import 'package:frontend_aicono/features/Authentication/domain/usecases/invitation_usecase.dart';

// Events
abstract class InvitationValidationEvent extends Equatable {
  const InvitationValidationEvent();

  @override
  List<Object?> get props => [];
}

class ValidateInvitation extends InvitationValidationEvent {
  final String token;

  const ValidateInvitation(this.token);

  @override
  List<Object?> get props => [token];
}

class CheckUserExistence extends InvitationValidationEvent {
  final String email;

  const CheckUserExistence(this.email);

  @override
  List<Object?> get props => [email];
}

// States
abstract class InvitationValidationState extends Equatable {
  const InvitationValidationState();

  @override
  List<Object?> get props => [];
}

class InvitationValidationInitial extends InvitationValidationState {}

class InvitationValidationLoading extends InvitationValidationState {}

class InvitationValidationSuccess extends InvitationValidationState {
  final InvitationEntity invitation;
  final bool userExists;

  const InvitationValidationSuccess({
    required this.invitation,
    required this.userExists,
  });

  @override
  List<Object?> get props => [invitation, userExists];
}

class InvitationValidationFailure extends InvitationValidationState {
  final String message;
  final bool isExpired;
  final InvitationEntity? invitation;

  const InvitationValidationFailure({
    required this.message,
    this.isExpired = false,
    this.invitation,
  });

  @override
  List<Object?> get props => [message, isExpired];
}

// BLoC
class InvitationValidationBloc
    extends Bloc<InvitationValidationEvent, InvitationValidationState> {
  final InvitationUseCase invitationUseCase;
  final LoginRepository loginRepository;

  InvitationValidationBloc({
    required this.invitationUseCase,
    required this.loginRepository,
  }) : super(InvitationValidationInitial()) {
    on<ValidateInvitation>(_onValidateInvitation);
    on<CheckUserExistence>(_onCheckUserExistence);
  }

  Future<void> _onValidateInvitation(
    ValidateInvitation event,
    Emitter<InvitationValidationState> emit,
  ) async {
    emit(InvitationValidationLoading());

    // First, get the invitation by token
    final invitationResult = await invitationUseCase.getInvitationByToken(
      event.token,
    );

    await invitationResult.fold(
      (failure) async {
        // Check if invitation is expired or not found
        final isExpired =
            failure.message.toLowerCase().contains('expired') ||
            failure.message.toLowerCase().contains('not found') ||
            failure.message.toLowerCase().contains('invalid');

        emit(
          InvitationValidationFailure(
            message: _mapFailureToMessage(failure),
            isExpired: isExpired,
          ),
        );
      },
      (invitation) async {
        // Check if invitation is expired by date
        if (invitation.expiresAt != null &&
            invitation.expiresAt!.isBefore(DateTime.now())) {
          emit(
            const InvitationValidationFailure(
              message: 'This invitation has expired',
              isExpired: true,
            ),
          );
          return;
        }

        // Check if invitation is already accepted
        if (invitation.isAccepted) {
          emit(
            InvitationValidationFailure(
              message: 'This invitation has already been accepted',
              invitation: invitation,
              isExpired: false,
            ),
          );
          return;
        }

        // Check whether a user already exists for the invitation email
        final existsResult = await loginRepository.checkUserExists(
          invitation.email,
        );
        final exists = existsResult.fold((_) => false, (v) => v);

        emit(
          InvitationValidationSuccess(
            invitation: invitation,
            userExists: exists,
          ),
        );
      },
    );
  }

  Future<void> _onCheckUserExistence(
    CheckUserExistence event,
    Emitter<InvitationValidationState> emit,
  ) async {
    emit(InvitationValidationLoading());

    final result = await loginRepository.checkUserExists(event.email);

    result.fold(
      (failure) => emit(
        InvitationValidationFailure(
          message: _mapFailureToMessage(failure),
          isExpired: false,
        ),
      ),
      (userExists) {
        // This event is typically used for re-checking,
        // but we need the invitation data to emit success
        // For now, we'll just handle the failure case
      },
    );
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        // Return the exact error message from the API
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
