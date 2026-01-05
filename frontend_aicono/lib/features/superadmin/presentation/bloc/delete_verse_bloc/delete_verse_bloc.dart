import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/delete_verse_usecase.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/delete_verse_bloc/delete_verse_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/delete_verse_bloc/delete_verse_state.dart';

class DeleteVerseBloc extends Bloc<DeleteVerseEvent, DeleteVerseState> {
  final DeleteVerseUseCase deleteVerseUseCase;

  DeleteVerseBloc({required this.deleteVerseUseCase})
    : super(DeleteVerseInitial()) {
    on<DeleteVerseRequested>(_onDeleteVerseRequested);
  }

  Future<void> _onDeleteVerseRequested(
    DeleteVerseRequested event,
    Emitter<DeleteVerseState> emit,
  ) async {
    emit(DeleteVerseLoading());

    final result = await deleteVerseUseCase(event.verseId);

    result.fold(
      (failure) => emit(DeleteVerseFailure(failure.message)),
      (_) => emit(DeleteVerseSuccess('Verse deleted successfully')),
    );
  }
}
