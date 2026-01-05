import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/superadmin/domain/repositories/verse_repository.dart';

class UpdateBryteSightMemberUseCase {
  final VerseRepository repository;

  UpdateBryteSightMemberUseCase({required this.repository});

  Future<Either<Failure, void>> call({
    required String bryteSightId,
    required String memberUserId,
    required String action,
  }) async {
    return await repository.updateBryteSightMember(
      bryteSightId: bryteSightId,
      memberUserId: memberUserId,
      action: action,
    );
  }
}
