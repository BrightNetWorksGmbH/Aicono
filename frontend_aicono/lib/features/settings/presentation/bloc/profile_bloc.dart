import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/features/settings/domain/entities/profile_update_request.dart';
import 'package:frontend_aicono/features/settings/domain/usecases/get_profile_usecase.dart';
import 'package:frontend_aicono/features/settings/domain/usecases/update_profile_usecase.dart';

// Events
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileRequested extends ProfileEvent {}

class ProfileUpdateSubmitted extends ProfileEvent {
  final ProfileUpdateRequest request;

  const ProfileUpdateSubmitted({required this.request});

  @override
  List<Object?> get props => [request];
}

// States
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final User user;

  const ProfileLoaded({required this.user});

  @override
  List<Object?> get props => [user];
}

class ProfileUpdating extends ProfileState {
  final User user;

  const ProfileUpdating({required this.user});

  @override
  List<Object?> get props => [user];
}

class ProfileUpdateSuccess extends ProfileState {
  final User user;

  const ProfileUpdateSuccess({required this.user});

  @override
  List<Object?> get props => [user];
}

class ProfileFailure extends ProfileState {
  final String message;

  const ProfileFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfileUseCase;
  final UpdateProfileUseCase updateProfileUseCase;

  ProfileBloc({
    required this.getProfileUseCase,
    required this.updateProfileUseCase,
  }) : super(ProfileInitial()) {
    on<ProfileRequested>(_onProfileRequested);
    on<ProfileUpdateSubmitted>(_onProfileUpdateSubmitted);
  }

  Future<void> _onProfileRequested(
    ProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());

    final result = await getProfileUseCase();

    result.fold(
      (failure) => emit(
        ProfileFailure(message: _mapFailureToMessage(failure)),
      ),
      (user) => emit(ProfileLoaded(user: user)),
    );
  }

  Future<void> _onProfileUpdateSubmitted(
    ProfileUpdateSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    final currentUser = state is ProfileLoaded
        ? (state as ProfileLoaded).user
        : state is ProfileUpdating
            ? (state as ProfileUpdating).user
            : null;
    if (currentUser != null) {
      emit(ProfileUpdating(user: currentUser));
    } else {
      emit(ProfileLoading());
    }

    final result = await updateProfileUseCase(event.request);

    result.fold(
      (failure) => emit(
        ProfileFailure(message: _mapFailureToMessage(failure)),
      ),
      (user) {
        sl<AuthService>().updateCurrentUser(user);
        emit(ProfileUpdateSuccess(user: user));
      },
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
