import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';

abstract class VerseState {}

class VerseInitial extends VerseState {}

class VerseLoading extends VerseState {}

class VerseCreateSuccess extends VerseState {
  final CreateVerseResponse response;

  VerseCreateSuccess(this.response);
}

class VersesLoaded extends VerseState {
  final List<VerseEntity> verses;

  VersesLoaded(this.verses);
}

class VerseFailure extends VerseState {
  final String message;

  VerseFailure(this.message);
}
