// upload_remote_data_source.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart'; // XFile works both on web & mobile
import 'package:http_parser/http_parser.dart';

import 'package:frontend_aicono/core/storage/secure_storage.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/token_service.dart';

abstract class UploadRemoteDataSource {
  Future<String> uploadImage(XFile image, String verseId, String folderPath);
}

class UploadRemoteDataSourceImpl implements UploadRemoteDataSource {
  final Dio dio;
  final TokenService tokenService;

  UploadRemoteDataSourceImpl({required this.dio, required this.tokenService});

  @override
  Future<String> uploadImage(
    XFile image,
    String verseId,
    String folderPath,
  ) async {
    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const ServerException("Authentication token missing");
    }

    MultipartFile multipartFile;

    if (kIsWeb) {
      // ✅ Web: read bytes from XFile
      final bytes = await image.readAsBytes();
      multipartFile = MultipartFile.fromBytes(
        bytes,
        filename: image.name,
        contentType: MediaType('image', 'jpeg'),
      );
    } else {
      // ✅ Mobile: just use path
      multipartFile = await MultipartFile.fromFile(
        image.path,
        filename: image.name,
        contentType: MediaType('image', 'jpeg'),
      );
    }

    final formData = FormData.fromMap({
      "file": multipartFile,
      "verse_id": verseId,
      "folder_path": folderPath,
    });

    try {
      final response = await dio.post(
        "https://brightcore-iugy8.ondigitalocean.app/upload/single",
        data: formData,
        options: Options(
          headers: {
            "Content-Type": "multipart/form-data",
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['file']['url'];
      } else {
        throw ServerException(
          "Upload failed with status ${response.statusCode}",
        );
      }
    } on DioException catch (e) {
      throw ServerException(ErrorExtractor.extractServerMessage(e));
    } catch (e) {
      throw ServerException('An unexpected error occurred: ${e.toString()}');
    }
  }
}
