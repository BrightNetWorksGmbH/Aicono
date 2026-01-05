import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/create_verse_usecase.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_create_bloc/verse_create_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_create_bloc/verse_create_state.dart';

class VerseCreateBloc extends Bloc<VerseCreateEvent, VerseCreateState> {
  final CreateVerseUseCase createVerseUseCase;

  VerseCreateBloc({required this.createVerseUseCase})
    : super(VerseCreateInitial()) {
    on<CreateVerseRequested>(_onCreateVerseRequested);
  }

  Future<void> _onCreateVerseRequested(
    CreateVerseRequested event,
    Emitter<VerseCreateState> emit,
  ) async {
    emit(VerseCreateLoading());

    final result = await createVerseUseCase(event.request);

    result.fold(
      (failure) => emit(VerseCreateFailure(failure.message)),
      (response) => emit(VerseCreateSuccess(response)),
    );
  }
}
