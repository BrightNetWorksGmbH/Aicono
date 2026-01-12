// presentation/bloc/upload_event.dart
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class UploadEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class UploadImageEvent extends UploadEvent {
  final XFile image;
  final String verseId;
  final String folderPath;

  UploadImageEvent(this.image, this.verseId, this.folderPath);

  @override
  List<Object?> get props => [image, verseId, folderPath];
}
