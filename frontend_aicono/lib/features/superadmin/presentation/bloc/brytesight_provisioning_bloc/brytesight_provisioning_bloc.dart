import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/set_brytesight_provisioning_usecase.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_provisioning_bloc/brytesight_provisioning_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/brytesight_provisioning_bloc/brytesight_provisioning_state.dart';

class BryteSightProvisioningBloc
    extends Bloc<BryteSightProvisioningEvent, BryteSightProvisioningState> {
  final SetBryteSightProvisioningUseCase setBryteSightProvisioningUseCase;

  BryteSightProvisioningBloc({required this.setBryteSightProvisioningUseCase})
    : super(BryteSightProvisioningInitial()) {
    on<SetBryteSightProvisioningRequested>(
      _onSetBryteSightProvisioningRequested,
    );
  }

  Future<void> _onSetBryteSightProvisioningRequested(
    SetBryteSightProvisioningRequested event,
    Emitter<BryteSightProvisioningState> emit,
  ) async {
    emit(BryteSightProvisioningLoading());

    final result = await setBryteSightProvisioningUseCase(
      event.verseId,
      event.canCreateBrytesight,
    );

    result.fold(
      (failure) => emit(BryteSightProvisioningFailure(failure.message)),
      (_) => emit(
        const BryteSightProvisioningSuccess(
          'BryteSight provisioning enabled successfully',
        ),
      ),
    );
  }
}
