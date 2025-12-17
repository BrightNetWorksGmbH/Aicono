import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }
}
