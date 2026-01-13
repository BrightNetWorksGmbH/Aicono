// domain/repositories/verse_file_repository.dart
import '../entities/verse_file.dart';

abstract class VerseFileRepository {
  Future<void> uploadVerseFile(VerseFile verseFile);
}
