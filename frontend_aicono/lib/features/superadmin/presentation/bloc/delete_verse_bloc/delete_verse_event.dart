abstract class DeleteVerseEvent {}

class DeleteVerseRequested extends DeleteVerseEvent {
  final String verseId;

  DeleteVerseRequested(this.verseId);
}
