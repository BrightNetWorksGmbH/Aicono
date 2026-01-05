import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class DeleteVerseUseCase {
  final VerseRepository repository;

  DeleteVerseUseCase({required this.repository});

  Future<Either<Failure, void>> call(String verseId) async {
    return await repository.deleteVerse(verseId);
  }
}
