import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/user_invite/domain/usecases/get_roles_usecase.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/roles_bloc/roles_event.dart';
import 'package:frontend_aicono/features/user_invite/presentation/bloc/roles_bloc/roles_state.dart';

class RolesBloc extends Bloc<RolesEvent, RolesState> {
  final GetRolesUseCase getRolesUseCase;

  RolesBloc({required this.getRolesUseCase}) : super(RolesInitial()) {
    on<RolesRequested>(_onRequested);
    on<RolesReset>((event, emit) => emit(RolesInitial()));
  }

  Future<void> _onRequested(
    RolesRequested event,
    Emitter<RolesState> emit,
  ) async {
    if (event.bryteswitchId.isEmpty) {
      emit(
        RolesFailure(message: 'invite_user.select_company_first_snackbar'.tr()),
      );
      return;
    }

    emit(RolesLoading());

    final result = await getRolesUseCase(event.bryteswitchId);
    result.fold(
      (failure) => emit(RolesFailure(message: _mapFailure(failure))),
      (roles) => emit(RolesSuccess(roles: roles)),
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
