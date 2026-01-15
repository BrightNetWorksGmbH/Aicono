import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/loxone_room_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/get_loxone_rooms_usecase.dart';

// Events
abstract class GetLoxoneRoomsEvent extends Equatable {
  const GetLoxoneRoomsEvent();

  @override
  List<Object?> get props => [];
}

class GetLoxoneRoomsSubmitted extends GetLoxoneRoomsEvent {
  final String buildingId;

  const GetLoxoneRoomsSubmitted({required this.buildingId});

  @override
  List<Object?> get props => [buildingId];
}

class GetLoxoneRoomsReset extends GetLoxoneRoomsEvent {}

// States
abstract class GetLoxoneRoomsState extends Equatable {
  const GetLoxoneRoomsState();

  @override
  List<Object?> get props => [];
}

class GetLoxoneRoomsInitial extends GetLoxoneRoomsState {}

class GetLoxoneRoomsLoading extends GetLoxoneRoomsState {}

class GetLoxoneRoomsSuccess extends GetLoxoneRoomsState {
  final List<LoxoneRoom> rooms;

  const GetLoxoneRoomsSuccess({required this.rooms});

  @override
  List<Object?> get props => [rooms];
}

class GetLoxoneRoomsFailure extends GetLoxoneRoomsState {
  final String message;

  const GetLoxoneRoomsFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class GetLoxoneRoomsBloc
    extends Bloc<GetLoxoneRoomsEvent, GetLoxoneRoomsState> {
  final GetLoxoneRoomsUseCase getLoxoneRoomsUseCase;

  GetLoxoneRoomsBloc({required this.getLoxoneRoomsUseCase})
      : super(GetLoxoneRoomsInitial()) {
    on<GetLoxoneRoomsSubmitted>(_onGetLoxoneRoomsSubmitted);
    on<GetLoxoneRoomsReset>(_onGetLoxoneRoomsReset);
  }

  Future<void> _onGetLoxoneRoomsSubmitted(
    GetLoxoneRoomsSubmitted event,
    Emitter<GetLoxoneRoomsState> emit,
  ) async {
    emit(GetLoxoneRoomsLoading());

    final result = await getLoxoneRoomsUseCase(event.buildingId);

    result.fold(
      (failure) => emit(GetLoxoneRoomsFailure(
          message: _mapFailureToMessage(failure))),
      (response) => emit(GetLoxoneRoomsSuccess(rooms: response.rooms)),
    );
  }

  void _onGetLoxoneRoomsReset(
    GetLoxoneRoomsReset event,
    Emitter<GetLoxoneRoomsState> emit,
  ) {
    emit(GetLoxoneRoomsInitial());
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return (failure as ServerFailure).message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

