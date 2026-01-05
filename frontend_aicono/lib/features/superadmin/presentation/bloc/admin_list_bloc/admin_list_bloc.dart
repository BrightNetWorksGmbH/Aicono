import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_aicono/features/superadmin/domain/usecases/get_verse_admins_usecase.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/admin_list_bloc/admin_list_event.dart';
import 'package:frontend_aicono/features/superadmin/presentation/bloc/admin_list_bloc/admin_list_state.dart';

class AdminListBloc extends Bloc<AdminListEvent, AdminListState> {
  final GetVerseAdminsUseCase getVerseAdminsUseCase;

  AdminListBloc({required this.getVerseAdminsUseCase})
    : super(AdminListInitial()) {
    on<LoadVerseAdminsRequested>(_onLoadVerseAdminsRequested);
  }

  Future<void> _onLoadVerseAdminsRequested(
    LoadVerseAdminsRequested event,
    Emitter<AdminListState> emit,
  ) async {
    emit(AdminListLoading());

    final result = await getVerseAdminsUseCase(event.verseId);

    result.fold(
      (failure) => emit(AdminListFailure(failure.message)),
      (admins) => emit(AdminListLoaded(admins)),
    );
  }
}
