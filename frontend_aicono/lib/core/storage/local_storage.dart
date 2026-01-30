import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/core/storage/secure_storage.dart';

class LocalStorage {
  final SharedPreferences prefs;

  static const String _userDataKey = 'cached_user_data';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _offlineQueueKey = 'offline_queue';
  // Public so other modules (e.g., AuthService) can clear it on logout
  static const String selectedVerseKey = 'selected_verse_id';
  static const String selectedSwitchKey = 'selected_switch_id';

  LocalStorage(this.prefs);

  /// Cache user data for offline access
  Future<void> cacheUserData(User user) async {
    try {
      final userJson = user.toJson();
      await prefs.setString(_userDataKey, jsonEncode(userJson));
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);

      await SecureStorage.saveTokens(user.token, user.refreshToken);
    } catch (e) {
      throw Exception('Failed to cache user data: $e');
    }
  }

  /// Get cached user data
  Future<User?> getCachedUserData() async {
    try {
      final userJsonString = prefs.getString(_userDataKey);
      if (userJsonString == null) return null;

      final userJson = jsonDecode(userJsonString) as Map<String, dynamic>;
      return User.fromJson(userJson);
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached user data
  Future<void> clearUserData() async {
    try {
      await prefs.remove(_userDataKey);
      await prefs.remove(_lastSyncKey);
      await SecureStorage.clearTokens();
    } catch (e) {
      throw Exception('Failed to clear user data: $e');
    }
  }

  /// Check if cached data is stale (older than specified hours)
  bool isCachedDataStale({int staleHours = 24}) {
    final lastSync = prefs.getInt(_lastSyncKey);
    if (lastSync == null) return true;

    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime);

    return difference.inHours > staleHours;
  }

  /// Queue offline actions for later sync
  Future<void> queueOfflineAction(
    String action,
    Map<String, dynamic> data,
  ) async {
    try {
      final queue = getOfflineQueue();
      queue.add({
        'action': action,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await prefs.setString(_offlineQueueKey, jsonEncode(queue));
    } catch (e) {
      throw Exception('Failed to queue offline action: $e');
    }
  }

  /// Get offline action queue
  List<Map<String, dynamic>> getOfflineQueue() {
    try {
      final queueString = prefs.getString(_offlineQueueKey);
      if (queueString == null) return [];

      final List<dynamic> queue = jsonDecode(queueString);
      return queue.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Clear offline action queue
  Future<void> clearOfflineQueue() async {
    await prefs.remove(_offlineQueueKey);
  }

  /// Process offline queue (call this when connectivity is restored)
  Future<List<Map<String, dynamic>>> processOfflineQueue() async {
    final queue = getOfflineQueue();
    await clearOfflineQueue();
    return queue;
  }

  /// Cache generic data
  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    await prefs.setString(key, jsonEncode(data));
  }

  /// Get cached generic data
  Future<Map<String, dynamic>?> getCachedData(String key) async {
    try {
      final dataString = prefs.getString(key);
      if (dataString == null) return null;

      return jsonDecode(dataString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Clear cached generic data
  Future<void> clearCachedData(String key) async {
    await prefs.remove(key);
  }

  /// Persist the currently selected verse id
  Future<void> setSelectedVerseId(String verseId) async {
    await prefs.setString(selectedVerseKey, verseId);
  }

  /// Get the currently selected verse id (if any)
  String? getSelectedVerseId() {
    return prefs.getString(selectedVerseKey);
  }

  /// Clear the selected verse id (e.g., on logout)
  Future<void> clearSelectedVerseId() async {
    await prefs.remove(selectedVerseKey);
  }

  /// Persist the currently selected switch id
  Future<void> setSelectedSwitchId(String switchId) async {
    await prefs.setString(selectedSwitchKey, switchId);
  }

  /// Get the currently selected switch id (if any)
  String? getSelectedSwitchId() {
    return prefs.getString(selectedSwitchKey);
  }

  /// Clear the selected switch id (e.g., on logout)
  Future<void> clearSelectedSwitchId() async {
    await prefs.remove(selectedSwitchKey);
  }
}
