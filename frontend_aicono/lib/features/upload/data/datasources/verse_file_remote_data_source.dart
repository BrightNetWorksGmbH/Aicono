// data/datasources/verse_file_remote_data_source.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:frontend_aicono/core/network/error_extractor.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/token_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../model/verse_file_model.dart';

abstract class VerseFileRemoteDataSource {
  Future<void> uploadVerseFile(VerseFileModel verseFile);
}

class VerseFileRemoteDataSourceImpl implements VerseFileRemoteDataSource {
  final Dio dio;
  final TokenService tokenService;

  VerseFileRemoteDataSourceImpl({
    required this.dio,
    required this.tokenService,
  });

  @override
  Future<void> uploadVerseFile(VerseFileModel verseFile) async {
    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const ServerException("Authentication token missing");
    }
    final body = verseFile.toJson();
    print(body);
    try {
      final response = await dio.post(
        "https://brightcore-iugy8.ondigitalocean.app/assets/create",
        data: jsonEncode(body),
        options: Options(
          headers: {
            "Content-Type": "application/json", // <--- use application/json
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        throw ServerException(" failed with status ${response.statusCode}");
      }
    } on DioException catch (e) {
      throw ServerException(ErrorExtractor.extractServerMessage(e));
    } catch (e) {
      throw ServerException('An unexpected error occurred: ${e.toString()}');
    }
  }
}
