import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/error/failure.dart';

abstract class UploadRepository {
  Future<Either<Failure, String>> uploadImage(
    XFile image,
    String verseId,
    String folderPath,
  );
}
