import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:cross_file/cross_file.dart';

/// Upload service using Dio for both web and mobile
class UploadService {
  final Dio _dio;

  UploadService({Dio? dio}) : _dio = dio ?? Dio();

  Future<Map<String, dynamic>> uploadFile({
    required String endpoint,
    required String token,
    required dynamic file, // XFile, String path, or Uint8List
    void Function(double progress)? onProgress,
    Map<String, String>? headers,
    String fieldName = 'file',
  }) async {
    MultipartFile multipartFile;

    if (kIsWeb) {
      // Web: use bytes
      if (file is Uint8List) {
        multipartFile = MultipartFile.fromBytes(
          file,
          filename: "upload_${DateTime.now().millisecondsSinceEpoch}.bin",
        );
      } else if (file is XFile) {
        final bytes = await file.readAsBytes();
        multipartFile = MultipartFile.fromBytes(bytes, filename: file.name);
      } else {
        throw Exception("On web, provide Uint8List or XFile");
      }
    } else {
      // Mobile/desktop: use file path
      if (file is String) {
        final fileName = p.basename(file);
        multipartFile = await MultipartFile.fromFile(file, filename: fileName);
      } else if (file is XFile) {
        multipartFile = await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        );
      } else {
        throw Exception("On mobile, provide file path or XFile");
      }
    }

    final formData = FormData.fromMap({fieldName: multipartFile});

    final response = await _dio.post(
      endpoint,
      data: formData,
      options: Options(
        headers: {
          "Content-Type": "multipart/form-data",
          "Authorization": "Bearer $token",
        },
      ),
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) {
          onProgress(sent / total);
        }
      },
    );

    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return response.data;
    }

    throw Exception('Upload failed: ${response.statusCode}');
  }
}
