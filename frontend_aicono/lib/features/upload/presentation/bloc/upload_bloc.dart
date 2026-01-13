// presentation/bloc/upload_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/upload_usecase.dart';
import 'upload_event.dart';
import 'upload_state.dart';

class UploadBloc extends Bloc<UploadEvent, UploadState> {
  final UploadImage uploadImage;

  UploadBloc(this.uploadImage) : super(UploadInitial()) {
    on<UploadImageEvent>(_onUploadImage);
  }

  Future<void> _onUploadImage(
    UploadImageEvent event,
    Emitter<UploadState> emit,
  ) async {
    emit(UploadLoading());
    final result = await uploadImage(
      event.image,
      event.verseId,
      event.folderPath,
    );
    result.fold(
      (failure) => emit(UploadFailure(failure.message)),
      (url) => emit(UploadSuccess(url)),
    );
  }
}
