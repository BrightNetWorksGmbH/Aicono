import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/entities/admin_entity.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class GetVerseAdminsUseCase {
  final VerseRepository repository;

  GetVerseAdminsUseCase({required this.repository});

  Future<Either<Failure, List<AdminEntity>>> call(String verseId) async {
    return await repository.getVerseAdmins(verseId);
  }
}
