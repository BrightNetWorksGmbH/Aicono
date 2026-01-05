import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';

abstract class VerseListState {}

class VerseListInitial extends VerseListState {}

class VerseListLoading extends VerseListState {}

class VersesLoaded extends VerseListState {
  final List<VerseEntity> verses;

  VersesLoaded(this.verses);
}

class VerseListFailure extends VerseListState {
  final String message;

  VerseListFailure(this.message);
}
