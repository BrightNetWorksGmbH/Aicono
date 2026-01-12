// presentation/bloc/upload_state.dart
import 'package:equatable/equatable.dart';

abstract class UploadState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UploadInitial extends UploadState {}

class UploadLoading extends UploadState {}

class UploadSuccess extends UploadState {
  final String url;

  UploadSuccess(this.url);

  @override
  List<Object?> get props => [url];
}

class UploadFailure extends UploadState {
  final String message;

  UploadFailure(this.message);

  @override
  List<Object?> get props => [message];
}
