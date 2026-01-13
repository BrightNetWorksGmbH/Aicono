// domain/usecases/upload_image.dart
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/error/failure.dart';
import '../repositories/upload_repository.dart';

class UploadImage {
  final UploadRepository repository;

  UploadImage(this.repository);

  Future<Either<Failure, String>> call(
    XFile image,
    String verseId,
    String folderPath,
  ) {
    return repository.uploadImage(image, verseId, folderPath);
  }
}
