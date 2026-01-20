import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_floors_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/get_floors_usecase.dart';

part 'get_floors_event.dart';
part 'get_floors_state.dart';

class GetFloorsBloc extends Bloc<GetFloorsEvent, GetFloorsState> {
  final GetFloorsUseCase getFloorsUseCase;

  GetFloorsBloc({required this.getFloorsUseCase}) : super(GetFloorsInitial()) {
    on<GetFloorsSubmitted>(_onGetFloorsSubmitted);
  }

  Future<void> _onGetFloorsSubmitted(
    GetFloorsSubmitted event,
    Emitter<GetFloorsState> emit,
  ) async {
    emit(GetFloorsLoading());

    final result = await getFloorsUseCase(event.buildingId);

    result.fold(
      (failure) => emit(GetFloorsFailure(message: failure.message)),
      (response) => emit(GetFloorsSuccess(floors: response.floors)),
    );
  }
}

