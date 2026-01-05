import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class GetBryteSightIdByVerseUseCase {
  final VerseRepository repository;

  GetBryteSightIdByVerseUseCase({required this.repository});

  Future<Either<Failure, String>> call(String verseId) async {
    return await repository.getBryteSightIdByVerse(verseId);
  }
}
