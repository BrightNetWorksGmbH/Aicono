import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/error/failure.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/repositories/upload_repository.dart';
import '../datasources/upload_remote_data_source.dart';

class UploadRepositoryImpl implements UploadRepository {
  final UploadRemoteDataSource remoteDataSource;

  UploadRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> uploadImage(
    XFile image,
    String verseId,
    String folderPath,
  ) async {
    try {
      final imageUrl = await remoteDataSource.uploadImage(
        image,
        verseId,
        folderPath,
      );
      return Right(imageUrl);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
