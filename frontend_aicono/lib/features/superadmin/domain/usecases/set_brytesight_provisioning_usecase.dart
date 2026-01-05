import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class SetBryteSightProvisioningUseCase {
  final VerseRepository repository;

  SetBryteSightProvisioningUseCase({required this.repository});

  Future<Either<Failure, void>> call(
    String verseId,
    bool canCreateBrytesight,
  ) async {
    return await repository.setBryteSightProvisioning(
      verseId,
      canCreateBrytesight,
    );
  }
}
