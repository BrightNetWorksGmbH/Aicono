import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/get_all_verses_usecase.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_list_bloc/verse_list_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_list_bloc/verse_list_state.dart';

class VerseListBloc extends Bloc<VerseListEvent, VerseListState> {
  final GetAllVersesUseCase getAllVersesUseCase;

  VerseListBloc({required this.getAllVersesUseCase})
    : super(VerseListInitial()) {
    on<LoadAllVersesRequested>(_onLoadAllVersesRequested);
  }

  Future<void> _onLoadAllVersesRequested(
    LoadAllVersesRequested event,
    Emitter<VerseListState> emit,
  ) async {
    emit(VerseListLoading());

    final result = await getAllVersesUseCase();

    result.fold(
      (failure) => emit(VerseListFailure(failure.message)),
      (verses) => emit(VersesLoaded(verses)),
    );
  }
}
