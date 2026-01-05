import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';

abstract class VerseCreateState {}

class VerseCreateInitial extends VerseCreateState {}

class VerseCreateLoading extends VerseCreateState {}

class VerseCreateSuccess extends VerseCreateState {
  final CreateVerseResponse response;

  VerseCreateSuccess(this.response);
}

class VerseCreateFailure extends VerseCreateState {
  final String message;

  VerseCreateFailure(this.message);
}
