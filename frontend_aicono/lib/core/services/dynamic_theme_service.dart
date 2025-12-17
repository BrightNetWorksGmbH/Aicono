import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/auth_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';

/// Service for managing dynamic theme colors based on user's joined verse
class DynamicThemeService extends ChangeNotifier {
  static final DynamicThemeService _instance = DynamicThemeService._internal();
  factory DynamicThemeService() => _instance;
  DynamicThemeService._internal();

  Color? _verseSurfaceColor;
  bool _isInitialized = false;

  Color? get verseSurfaceColor => _verseSurfaceColor;
  bool get isInitialized => _isInitialized;

  /// Initialize the dynamic theme service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final authService = sl<AuthService>();
      final localStorage = sl<LocalStorage>();

      // Check if user is authenticated and has joined verses
      if (authService.isAuthenticated && authService.currentUser != null) {
        final user = authService.currentUser!;

        if (user.joinedVerse.isNotEmpty) {
          // Prefer the selected verse from local storage, fallback to first
          final saved = localStorage.getSelectedVerseId();
          final verseId = (saved != null && user.joinedVerse.contains(saved))
              ? saved
              : user.joinedVerse.first;
          print('DynamicThemeService: Loading verse for theme - ID: $verseId');
        } else {
          print('DynamicThemeService: No joined verses found');
        }
      } else {
        print('DynamicThemeService: User not authenticated');
      }
    } catch (e) {
      print('Error initializing dynamic theme: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Force refresh theme (useful after login/logout)
  Future<void> refreshTheme() async {
    _isInitialized = false;
    await initialize();
  }

  /// Check if user has joined verses
  bool get hasJoinedVerse {
    final authService = sl<AuthService>();
    return authService.isAuthenticated &&
        authService.currentUser != null &&
        authService.currentUser!.joinedVerse.isNotEmpty;
  }

  /// Get current surface color (verse-based or default)
  Color getCurrentSurfaceColor() {
    if (hasJoinedVerse && _verseSurfaceColor != null) {
      return _verseSurfaceColor!;
    }
    return const Color(0xFF161B22); // Default black surface
  }
}

/// Extension to convert Color to hex string
extension ColorExtension on Color {
  String toHex() {
    return '#${value.toRadixString(16).substring(2).toUpperCase()}';
  }
}
