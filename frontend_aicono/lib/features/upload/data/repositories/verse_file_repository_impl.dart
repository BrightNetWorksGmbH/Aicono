// data/repositories/verse_file_repository_impl.dart
import '../../domain/entities/verse_file.dart';
import '../../domain/repositories/verse_file_repository.dart';
import '../datasources/verse_file_remote_data_source.dart';
import '../model/verse_file_model.dart';

class VerseFileRepositoryImpl implements VerseFileRepository {
  final VerseFileRemoteDataSource remoteDataSource;

  VerseFileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> uploadVerseFile(VerseFile verseFile) async {
    // Convert entity to model
    final model = VerseFileModel.fromEntity(verseFile);
    await remoteDataSource.uploadVerseFile(model);
  }
}
