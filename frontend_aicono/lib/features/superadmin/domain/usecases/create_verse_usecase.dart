import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/verse_entity.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class CreateVerseUseCase {
  final VerseRepository repository;

  CreateVerseUseCase({required this.repository});

  Future<Either<Failure, CreateVerseResponse>> call(
    CreateVerseRequest request,
  ) async {
    return await repository.createVerse(request);
  }
}
