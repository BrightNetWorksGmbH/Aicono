import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/create_verse_usecase.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/get_all_verses_usecase.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_bloc/verse_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/verse_bloc/verse_state.dart';

class SuperadminVerseBloc extends Bloc<VerseEvent, VerseState> {
  final CreateVerseUseCase createVerseUseCase;
  final GetAllVersesUseCase getAllVersesUseCase;

  SuperadminVerseBloc({
    required this.createVerseUseCase,
    required this.getAllVersesUseCase,
  }) : super(VerseInitial()) {
    on<CreateVerseRequested>(_onCreateVerseRequested);
    on<LoadAllVersesRequested>(_onLoadAllVersesRequested);
  }

  Future<void> _onCreateVerseRequested(
    CreateVerseRequested event,
    Emitter<VerseState> emit,
  ) async {
    emit(VerseLoading());

    final result = await createVerseUseCase(event.request);

    result.fold((failure) => emit(VerseFailure(failure.message)), (response) {
      emit(VerseCreateSuccess(response));
      // Automatically reload the list after creation
      add(LoadAllVersesRequested());
    });
  }

  Future<void> _onLoadAllVersesRequested(
    LoadAllVersesRequested event,
    Emitter<VerseState> emit,
  ) async {
    // Don't show loading when refreshing the list after creation
    if (state is! VerseCreateSuccess) {
      emit(VerseLoading());
    }

    final result = await getAllVersesUseCase();

    result.fold(
      (failure) => emit(VerseFailure(failure.message)),
      (verses) => emit(VersesLoaded(verses)),
    );
  }
}
