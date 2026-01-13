// // presentation/bloc/verse_file_bloc.dart
// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui' as ui;

// import 'package:dio/dio.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:image_picker/image_picker.dart';
// import '../../../../core/error/exceptions.dart';
// import '../../../../core/network/error_extractor.dart';
// import '../../domain/entities/verse_file.dart';
// import '../../domain/usecases/upload_usecase.dart';
// import '../../domain/usecases/upload_verse_file.dart';

// abstract class VerseFileEvent {}

// class UploadVerseFileEvent extends VerseFileEvent {
//   final VerseFile verseFile;
//   final XFile image;

//   UploadVerseFileEvent(this.verseFile, this.image);
// }

// abstract class VerseFileState {}

// class VerseFileInitial extends VerseFileState {}

// class VerseFileProgress extends VerseFileState {
//   final double progress;
//   VerseFileProgress(this.progress);
// }

// class VerseFileLoading extends VerseFileState {}

// class VerseFileSuccess extends VerseFileState {}

// class VerseFileError extends VerseFileState {
//   final String message;
//   VerseFileError(this.message);
// }

// class VerseFileBloc extends Bloc<VerseFileEvent, VerseFileState> {
//   final UploadVerseFile uploadVerseFile;
//   final UploadImage uploadImage;
//   // final UploadFileServiceUsecase uploadFileServiceUsecase;
//   final FileUploadServiceBloc fileUploadBloc;

//   VerseFileBloc({
//     required this.uploadVerseFile,
//     required this.uploadImage,
//     // required this.uploadFileServiceUsecase,
//     required this.fileUploadBloc,
//   }) : super(VerseFileInitial()) {
//     on<UploadVerseFileEvent>((event, emit) async {
//       emit(VerseFileLoading());

//       late StreamSubscription uploadSubscription;

//       try {
//         // 1️⃣ Start listening to upload progress from FileUploadServiceBloc
//         uploadSubscription = fileUploadBloc.stream.listen((fileState) {
//           if (fileState is UploadFileServicesInProgress) {
//             emit(VerseFileProgress(fileState.progress));
//           }
//         });

//         // 2️⃣ Trigger upload via FileUploadServiceBloc
//         // final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
//         fileUploadBloc.add(
//           UploadFileServiceRequested(event.image, "manual_metadata_creation"),
//         );

//         // 3️⃣ Wait until upload finishes (success or failure)
//         final uploadedFileState = await fileUploadBloc.stream.firstWhere(
//           (state) =>
//               state is UploadFileServicesSuccess ||
//               state is UploadFileServicesFailure,
//         );

//         // Stop listening once we got a final state
//         await uploadSubscription.cancel();

//         // Check if upload failed
//         if (uploadedFileState is UploadFileServicesFailure) {
//           // The error message is already extracted in FileUploadServiceBloc
//           // Just throw it so it gets caught and handled
//           throw Exception(uploadedFileState.message);
//         }

//         final uploaded = (uploadedFileState as UploadFileServicesSuccess).file;
//         final fileUrl = uploaded.cdnUrl;
//         final originalName = uploaded.originalName;
//         // final uploadFileResult = await uploadFileServiceUsecase(
//         //   file: event.image,
//         //   onProgress: (p) {
//         //     add(UploadFileServiceProgressChanged(p));
//         //   },
//         // );
//         // String fileUrl = uploadFileResult.cdnUrl;

//         if (fileUrl.isEmpty) {
//           return;
//         }

//         // // 2) Extract metadata (dimensions only for images)
//         // final info = uploadFileResult;
//         // // Determine extension and file type mapping accepted by backend
//         // final originalName = uploadFileResult.originalName;
//         final ext = originalName.contains('.')
//             ? originalName.split('.').last.toLowerCase()
//             : '';

//         String mapFileType(String extension) {
//           final imageExt = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'tiff'];
//           final videoExt = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
//           final audioExt = ['mp3', 'wav', 'aac', 'ogg'];
//           final pdfExt = ['pdf'];
//           final archiveExt = ['zip', 'rar', '7z', 'tar', 'gz'];
//           final documentExt = ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'];
//           final textExt = ['txt', 'csv', 'md', 'json', 'xml'];

//           if (imageExt.contains(extension)) return 'image';
//           if (videoExt.contains(extension)) return 'video';
//           if (audioExt.contains(extension)) return 'audio';
//           if (pdfExt.contains(extension)) return 'pdf';
//           if (archiveExt.contains(extension)) return 'archive';
//           if (documentExt.contains(extension)) return 'document';
//           if (textExt.contains(extension)) return 'text';
//           return 'data';
//         }

//         final fileType = mapFileType(ext);

//         // For images, extract dimensions; otherwise set to 0
//         Future<Map<String, dynamic>> _extractImageInfo(
//           XFile file,
//           String extension,
//         ) async {
//           String originalFilename = file.name;
//           // Use the extension parameter passed in
//           if (originalFilename.contains('.') && extension.isEmpty) {
//             extension = originalFilename.split('.').last.toLowerCase();
//           }

//           int size = 0;
//           Uint8List bytes = Uint8List(0);
//           // Try to read bytes from XFile first. This works for files created from
//           // bytes (XFile.fromData) and for many platform implementations.
//           try {
//             bytes = await file.readAsBytes();
//             size = bytes.lengthInBytes;
//           } catch (e) {
//             // Fallback: try reading from the filesystem path (mobile)
//             try {
//               if (!kIsWeb && file.path.isNotEmpty) {
//                 final f = File(file.path);
//                 if (await f.exists()) {
//                   bytes = await f.readAsBytes();
//                   size = await f.length();
//                 }
//               }
//             } catch (_) {
//               // leave bytes empty/size 0 on failure
//               bytes = Uint8List(0);
//               size = 0;
//             }
//           }

//           int width = 100;
//           int height = 100;

//           final imageExt = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'tiff'];
//           if (imageExt.contains(extension.toLowerCase()) && bytes.isNotEmpty) {
//             try {
//               final completer = Completer<Map<String, int>>();
//               ui.decodeImageFromList(bytes, (ui.Image img) {
//                 completer.complete({'width': img.width, 'height': img.height});
//               });
//               final dims = await completer.future;
//               width = dims['width'] ?? 100;
//               height = dims['height'] ?? 100;
//             } catch (_) {
//               // ignore image decode errors for non-image or corrupted data
//               width = 100;
//               height = 100;
//             }
//           }

//           final baseName = originalFilename.contains('.')
//               ? originalFilename.substring(0, originalFilename.lastIndexOf('.'))
//               : originalFilename;

//           final isImage = [
//             'png',
//             'jpg',
//             'jpeg',
//             'gif',
//             'webp',
//             'bmp',
//             'tiff',
//           ].contains(extension.toLowerCase());

//           return {
//             'original_filename': originalFilename,
//             'extension': extension,
//             'size': size,
//             'width': width,
//             'height': height,
//             'name': baseName,
//             'is_image': isImage,
//           };
//         }

//         int width = 100;
//         int height = 100;
//         Map<String, dynamic> info = await _extractImageInfo(event.image, ext);
//         width = info['width'] ?? 100;
//         height = info['height'] ?? 100;

//         // 3) Build VerseFile entity and call UploadVerseFile usecase
//         //     final currentVerseId = _getVerseId() ?? '';
//         //     final verseFile = VerseFile(
//         //       verseId: currentVerseId,
//         //       channelId: _selectedChannelId!,
//         //       name: info.originalName,
//         //       originalFilename: info.originalName,
//         //       fileType: fileType,
//         //       fileExtension: ext,
//         //       fileSize: info.size,
//         //       fileUrl: fileUrl,
//         //       thumbnailUrl: fileUrl,
//         //       folderPath: '/verse/$currentVerseId',
//         //       fileMetadata: FileMetadata(
//         //         dimensions: Dimensions(width: width, height: height),
//         //         resolution: Resolution(dpi: 72),
//         //         colorMode: 'rgb',
//         //       ),
//         //       metadataData: MetadataData(
//         //         imageFileInfo: ImageFileInfo(
//         //           title: info.fileName,
//         //           altText: '',
//         //           description: '',
//         //           tags: [],
//         //           keywords: [],
//         //           subjectName: '',
//         //           location: '',
//         //           dateTaken: DateTime.now().toIso8601String(),
//         //         ),
//         //         copyrightInfo: CopyrightInfo(
//         //           // backend expects one of: protected, public_domain, creative_commons, fair_use, licensed, unknown
//         //           status: 'unknown',
//         //           holder: '',
//         //           year: DateTime.now().year,
//         //           notice: '',
//         //           // license_type must be one of: all_rights_reserved, creative_commons, public_domain, fair_use, custom
//         //           licenseType: 'custom',
//         //           usageRights: '',
//         //         ),
//         //         creatorUsage: CreatorUsage(
//         //           // creator_type must be one of: bright_networks, external, unknown
//         //           creatorType: 'unknown',
//         //           isBrightNetworksCreator: false,
//         //           creatorName: '',
//         //           creatorContact: CreatorContact(
//         //             // must be valid email/URL
//         //             email: 'no-reply@brightnetworks.com',
//         //             website: 'https://example.com',
//         //           ),
//         //           attributionRequired: false,
//         //           commercialUseAllowed: false,
//         //           modificationAllowed: false,
//         //         ),
//         //         imageDescription: ImageDescription(
//         //           description: '',
//         //           generatedByAi: false,
//         //           manuallyEntered: false,
//         //           accessibilityNotes: '',
//         //         ),
//         //         searchKeywords: SearchKeywords(
//         //           seoKeywords: [],
//         //           verseSearchKeyword: [],
//         //           categoryTags: [],
//         //           industryTags: [],
//         //           generatedByAi: false,
//         //           manuallyEntered: false,
//         //         ),
//         //         internalNotes: InternalNotes(
//         //           notes: '',
//         //           priority: 'medium',
//         //           reviewRequired: false,
//         //           reviewerNotes: '',
//         //         ),
//         //       ),
//         //     );

//         //     // final uploadVerseUsecase = sl<UploadVerseFile>();
//         //     // await uploadVerseUsecase(verseFile);

//         //     // Notify via AssetCreateBloc to keep current flows (optional)
//         //     final Map<String, dynamic> body = {
//         //       'verse_id': verseFile.verseId,
//         //       'channel_id': verseFile.channelId,
//         //       'name': verseFile.name,
//         //       'original_filename': verseFile.originalFilename,
//         //       'file_type': verseFile.fileType,
//         //       'file_extension': verseFile.fileExtension,
//         //       'file_size': verseFile.fileSize,
//         //       'file_url': verseFile.fileUrl,
//         //       'file_metadata': {
//         //         'dimensions': {
//         //           'width': verseFile.fileMetadata.dimensions.width,
//         //           'height': verseFile.fileMetadata.dimensions.height,
//         //         },
//         //         'resolution': {'dpi': verseFile.fileMetadata.resolution.dpi},
//         //         'color_mode': verseFile.fileMetadata.colorMode,
//         //       },
//         //       'metadata_data': {
//         //         'image_file_info': {
//         //           'title': verseFile.metadataData.imageFileInfo.title,
//         //           'description': verseFile.metadataData.imageFileInfo.description,
//         //         },
//         //       },
//         //     }..removeWhere((k, v) => v == null);

//         //     context.read<AssetCreateBloc>().add(SubmitAssetCreateEvent(body));
//         //   } catch (e) {
//         //     setState(() => _uploading = false);

//         //     if (!mounted) return;
//         //     final errorMsg = e is DioException
//         //         ? ErrorExtractor.extractServerMessage(e)
//         //         : e.toString();
//         //     ScaffoldMessenger.of(context).showSnackBar(
//         //       SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
//         //     );
//         //   }
//         // }

//         // Future<XFile> _toXFile() async {
//         //   if (_imageBytes != null && kIsWeb) {
//         //     return XFile.fromData(
//         //       _imageBytes!,
//         //       name: _pickedFile?.name ?? 'upload.png',
//         //       mimeType: 'image/png',
//         //     );
//         //   }
//         //   if (_pickedFile != null) return _pickedFile!;
//         //   throw Exception('No image selected');
//         // }

//         final updateSettings = event.verseFile.copyWith(
//           name: info['original_filename'] ?? 'Untitled Image',
//           originalFilename: info['original_filename'] ?? 'upload.png',
//           fileType: fileType,
//           fileExtension: ext ?? 'png',
//           fileSize: info['size'] ?? 0,
//           fileUrl: fileUrl,
//           thumbnailUrl: fileUrl,
//         );

//         final updatedResult = await uploadVerseFile(updateSettings);

//         emit(VerseFileSuccess());
//       } catch (e) {
//         String errorMessage;
//         if (e is ServerException) {
//           // ServerException already contains the extracted error message
//           errorMessage = e.message;
//         } else if (e is DioException) {
//           errorMessage = ErrorExtractor.extractServerMessage(e);
//         } else {
//           // For other exceptions, use toString but try to extract meaningful message
//           errorMessage = e.toString();
//           // If it's a generic exception string, try to extract just the message part
//           if (errorMessage.startsWith('Exception: ')) {
//             errorMessage = errorMessage.substring('Exception: '.length);
//           } else if (errorMessage.startsWith('ServerException: ')) {
//             errorMessage = errorMessage.substring('ServerException: '.length);
//           }
//         }
//         emit(VerseFileError(errorMessage));
//       }
//     });
//   }
// }
