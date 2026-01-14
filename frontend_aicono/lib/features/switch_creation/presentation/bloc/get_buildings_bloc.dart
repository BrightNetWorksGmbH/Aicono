import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_buildings_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/get_buildings_usecase.dart';

// Events
abstract class GetBuildingsEvent extends Equatable {
  const GetBuildingsEvent();

  @override
  List<Object?> get props => [];
}

class GetBuildingsRequested extends GetBuildingsEvent {
  final String siteId;

  const GetBuildingsRequested({required this.siteId});

  @override
  List<Object?> get props => [siteId];
}

class GetBuildingsReset extends GetBuildingsEvent {}

// States
abstract class GetBuildingsState extends Equatable {
  const GetBuildingsState();

  @override
  List<Object?> get props => [];
}

class GetBuildingsInitial extends GetBuildingsState {}

class GetBuildingsLoading extends GetBuildingsState {}

class GetBuildingsSuccess extends GetBuildingsState {
  final List<BuildingData> buildings;

  const GetBuildingsSuccess({required this.buildings});

  @override
  List<Object?> get props => [buildings];
}

class GetBuildingsFailure extends GetBuildingsState {
  final String message;

  const GetBuildingsFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class GetBuildingsBloc extends Bloc<GetBuildingsEvent, GetBuildingsState> {
  final GetBuildingsUseCase getBuildingsUseCase;

  GetBuildingsBloc({required this.getBuildingsUseCase})
      : super(GetBuildingsInitial()) {
    on<GetBuildingsRequested>(_onGetBuildingsRequested);
    on<GetBuildingsReset>(_onGetBuildingsReset);
  }

  Future<void> _onGetBuildingsRequested(
    GetBuildingsRequested event,
    Emitter<GetBuildingsState> emit,
  ) async {
    emit(GetBuildingsLoading());

    final result = await getBuildingsUseCase(event.siteId);

    result.fold(
      (failure) => emit(GetBuildingsFailure(message: _mapFailureToMessage(failure))),
      (response) => emit(GetBuildingsSuccess(buildings: response.buildings)),
    );
  }

  void _onGetBuildingsReset(
    GetBuildingsReset event,
    Emitter<GetBuildingsState> emit,
  ) {
    emit(GetBuildingsInitial());
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return (failure as ServerFailure).message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      case CacheFailure:
        return 'Cache error occurred.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
