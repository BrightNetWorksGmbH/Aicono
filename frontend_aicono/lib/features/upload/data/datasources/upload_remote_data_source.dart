// upload_remote_data_source.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart'; // XFile works both on web & mobile
import 'package:http_parser/http_parser.dart';

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
      // Let AuthInterceptor handle the Authorization header
      // Dio automatically sets Content-Type for FormData, so we don't need to set it manually
      final response = await dio.post("/api/v1/upload/single", data: formData);

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Check for success flag and data wrapper
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          // Use url or cdnUrl (prefer cdnUrl if available)
          final url = data['cdnUrl'] ?? data['url'];
          if (url != null && url is String) {
            return url;
          } else {
            throw ServerException(
              'Invalid response format: missing url in data',
            );
          }
        } else {
          throw ServerException(
            'Invalid response format: success flag is false or data is missing',
          );
        }
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
