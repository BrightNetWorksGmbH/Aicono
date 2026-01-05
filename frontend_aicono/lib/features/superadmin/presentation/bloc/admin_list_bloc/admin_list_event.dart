abstract class AdminListEvent {}

class LoadVerseAdminsRequested extends AdminListEvent {
  final String verseId;

  LoadVerseAdminsRequested(this.verseId);
}
