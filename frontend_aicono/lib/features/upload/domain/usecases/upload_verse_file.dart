// domain/usecases/upload_verse_file.dart
import '../entities/verse_file.dart';
import '../repositories/verse_file_repository.dart';

class UploadVerseFile {
  final VerseFileRepository repository;

  UploadVerseFile(this.repository);

  Future<void> call(VerseFile verseFile) async {
    await repository.uploadVerseFile(verseFile);
  }
}
