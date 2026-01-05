import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class GetAllVersesUseCase {
  final VerseRepository repository;

  GetAllVersesUseCase({required this.repository});

  Future<Either<Failure, List<VerseEntity>>> call() async {
    return await repository.getAllVerses();
  }
}
