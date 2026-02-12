import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/dynamic_theme_service.dart';
import 'package:frontend_aicono/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/user.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/login_repository.dart';

class AuthService {
  final LoginRepository _loginRepository;
  User? _currentUser;
  bool _isInitialized = false;

  AuthService(this._loginRepository);

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;

  /// Initialize authentication state by checking for existing user
  Future<void> initialize() async {
    if (_isInitialized) return;

    final result = await _loginRepository.getCurrentUser();
    result.fold(
      (failure) {
        _currentUser = null;
        _isInitialized = true;
      },
      (user) {
        _currentUser = user;
        _isInitialized = true;
      },
    );
  }

  /// Login user and update authentication state
  Future<Either<Failure, User>> login(String email, String password) async {
    final result = await _loginRepository.login(email, password);
    result.fold((failure) => null, (user) {
      _currentUser = user;
      // Persist user to SharedPreferences as an additional safeguard
      try {
        final prefs = sl<SharedPreferences>();
        prefs.setString('user_data', user.toJsonString());
      } catch (_) {}
      // Refresh theme after login
      sl<DynamicThemeService>().refreshTheme();
    });
    return result;
  }

  /// Logout user and clear authentication state
  Future<Either<Failure, void>> logout() async {
    final result = await _loginRepository.logout();
    // Regardless of server outcome, clear local auth/session to ensure logout
    _currentUser = null;
    try {
      final prefs = sl<SharedPreferences>();
      await prefs.remove('user_data');
      await sl<LocalStorage>().clearSelectedVerseId();
    } catch (_) {}
    // Refresh theme after logout
    await sl<DynamicThemeService>().refreshTheme();
    return result;
  }

  /// Clear authentication state (for logout)
  void clearAuth() {
    _currentUser = null;
  }

  /// Update current user in memory and persist (e.g. after profile update)
  void updateCurrentUser(User user) {
    _currentUser = user;
    try {
      final prefs = sl<SharedPreferences>();
      prefs.setString('user_data', user.toJsonString());
    } catch (_) {}
    sl<DynamicThemeService>().refreshTheme();
  }

  /// Update current user's joined verse list in memory and persist if needed
  void addJoinedVerse(String verseId) {
    if (_currentUser == null) return;
    if (!_currentUser!.joinedVerse.contains(verseId)) {
      _currentUser!.joinedVerse.add(verseId);
      // Persist updated user so refresh keeps the state
      try {
        final prefs = sl<SharedPreferences>();
        prefs.setString('user_data', _currentUser!.toJsonString());
      } catch (_) {}
      // Inform theme service that verse context changed
      sl<DynamicThemeService>().refreshTheme();
    }
  }

  /// Refresh user profile from server to get latest data
  /// This ensures verse memberships and other user data are up to date
  Future<Either<Failure, User>> refreshProfile() async {
    try {
      final result = await _loginRepository.fetchProfile();
      return result.fold((failure) => Left(failure), (user) {
        // Update current user with fresh data
        _currentUser = user;

        // Persist updated user data
        try {
          final prefs = sl<SharedPreferences>();
          prefs.setString('user_data', user.toJsonString());
        } catch (_) {}

        // Refresh theme in case verse changed
        sl<DynamicThemeService>().refreshTheme();

        return Right(user);
      });
    } catch (e) {
      return Left(ServerFailure('Failed to refresh profile: $e'));
    }
  }
}
