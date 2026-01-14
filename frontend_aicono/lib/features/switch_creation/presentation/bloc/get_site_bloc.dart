import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/switch_creation/domain/entities/get_site_entity.dart';
import 'package:frontend_aicono/features/switch_creation/domain/usecases/get_site_usecase.dart';

// Events
abstract class GetSiteEvent extends Equatable {
  const GetSiteEvent();

  @override
  List<Object?> get props => [];
}

class GetSiteRequested extends GetSiteEvent {
  final String siteId;

  const GetSiteRequested({required this.siteId});

  @override
  List<Object?> get props => [siteId];
}

class GetSiteReset extends GetSiteEvent {}

// States
abstract class GetSiteState extends Equatable {
  const GetSiteState();

  @override
  List<Object?> get props => [];
}

class GetSiteInitial extends GetSiteState {}

class GetSiteLoading extends GetSiteState {}

class GetSiteSuccess extends GetSiteState {
  final SiteData siteData;

  const GetSiteSuccess({required this.siteData});

  @override
  List<Object?> get props => [siteData];
}

class GetSiteFailure extends GetSiteState {
  final String message;

  const GetSiteFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class GetSiteBloc extends Bloc<GetSiteEvent, GetSiteState> {
  final GetSiteUseCase getSiteUseCase;

  GetSiteBloc({required this.getSiteUseCase}) : super(GetSiteInitial()) {
    on<GetSiteRequested>(_onGetSiteRequested);
    on<GetSiteReset>(_onGetSiteReset);
  }

  Future<void> _onGetSiteRequested(
    GetSiteRequested event,
    Emitter<GetSiteState> emit,
  ) async {
    emit(GetSiteLoading());

    final result = await getSiteUseCase(event.siteId);

    result.fold(
      (failure) => emit(GetSiteFailure(message: _mapFailureToMessage(failure))),
      (response) {
        if (response.data != null) {
          emit(GetSiteSuccess(siteData: response.data!));
        } else {
          emit(const GetSiteFailure(message: 'Site data not found'));
        }
      },
    );
  }

  void _onGetSiteReset(
    GetSiteReset event,
    Emitter<GetSiteState> emit,
  ) {
    emit(GetSiteInitial());
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
