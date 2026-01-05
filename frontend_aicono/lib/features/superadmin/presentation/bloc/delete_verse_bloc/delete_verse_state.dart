abstract class DeleteVerseState {}

class DeleteVerseInitial extends DeleteVerseState {}

class DeleteVerseLoading extends DeleteVerseState {}

class DeleteVerseSuccess extends DeleteVerseState {
  final String message;

  DeleteVerseSuccess(this.message);
}

class DeleteVerseFailure extends DeleteVerseState {
  final String message;

  DeleteVerseFailure(this.message);
}
