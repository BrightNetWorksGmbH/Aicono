import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  // Configure FlutterSecureStorage for web compatibility
  // Using default options which should work on all platforms including web
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    // Web options - use localStorage (not sessionStorage)
    webOptions: WebOptions(
      useSessionStorage: false,
    ),
  );
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _accessTokenKey);
      if (kDebugMode) {
        print('🔑 SecureStorage.getAccessToken: ${token != null ? "Token found (${token.length} chars)" : "No token"}');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SecureStorage.getAccessToken error: $e');
      }
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _refreshTokenKey);
      if (kDebugMode) {
        print('🔑 SecureStorage.getRefreshToken: ${token != null ? "Token found" : "No token"}');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SecureStorage.getRefreshToken error: $e');
      }
      return null;
    }
  }

  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      if (kDebugMode) {
        print('✅ SecureStorage.saveTokens: Tokens saved successfully (access: ${accessToken.length} chars)');
        // Verify it was saved
        final verifyToken = await _storage.read(key: _accessTokenKey);
        print('🔍 SecureStorage.saveTokens verification: ${verifyToken != null ? "Token verified" : "⚠️ Token NOT found after save!"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SecureStorage.saveTokens error: $e');
      }
      rethrow;
    }
  }

  static Future<void> clearTokens() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      if (kDebugMode) {
        print('🗑️ SecureStorage.clearTokens: Tokens cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SecureStorage.clearTokens error: $e');
      }
    }
  }
}
