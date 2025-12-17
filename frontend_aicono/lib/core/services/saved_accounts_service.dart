import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAccount {
  final String email;
  final String password;
  final DateTime savedAt;
  final String? firstName;
  final String? lastName;

  SavedAccount({
    required this.email,
    required this.password,
    required this.savedAt,
    this.firstName,
    this.lastName,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'savedAt': savedAt.toIso8601String(),
      'firstName': firstName,
      'lastName': lastName,
    };
  }

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      email: json['email'],
      password: json['password'],
      savedAt: DateTime.parse(json['savedAt']),
      firstName: json['firstName'],
      lastName: json['lastName'],
    );
  }
}

class SavedAccountsService {
  static const String _savedAccountsKey = 'saved_accounts';
  static const String _lastUsedAccountKey = 'last_used_account';
  static const int _maxSavedAccounts = 5; // Limit to prevent storage bloat

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  SavedAccountsService({
    required SharedPreferences prefs,
    required FlutterSecureStorage secureStorage,
  }) : _prefs = prefs,
       _secureStorage = secureStorage;

  /// Save an account with encrypted password
  Future<void> saveAccount({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      // Get existing accounts
      final existingAccounts = await getSavedAccounts();

      // Remove if account already exists
      existingAccounts.removeWhere((account) => account.email == email);

      // Create new account
      final newAccount = SavedAccount(
        email: email,
        password: password,
        savedAt: DateTime.now(),
        firstName: firstName,
        lastName: lastName,
      );

      // Add to beginning of list
      existingAccounts.insert(0, newAccount);

      // Limit to max accounts
      if (existingAccounts.length > _maxSavedAccounts) {
        existingAccounts.removeRange(
          _maxSavedAccounts,
          existingAccounts.length,
        );
      }

      // Save accounts list
      final accountsJson = existingAccounts.map((a) => a.toJson()).toList();
      await _prefs.setString(_savedAccountsKey, jsonEncode(accountsJson));
      print(
        'SavedAccountsService: Saved ${existingAccounts.length} accounts to SharedPreferences',
      );

      // Save encrypted passwords separately
      for (final account in existingAccounts) {
        await _secureStorage.write(
          key: 'password_${account.email}',
          value: account.password,
        );
        print(
          'SavedAccountsService: Saved encrypted password for: ${account.email}',
        );
      }

      // Set as last used account
      await _prefs.setString(_lastUsedAccountKey, email);
    } catch (e) {
      print('Error saving account: $e');
    }
  }

  /// Get all saved accounts
  Future<List<SavedAccount>> getSavedAccounts() async {
    try {
      final accountsJson = _prefs.getString(_savedAccountsKey);
      print('SavedAccountsService: accountsJson = $accountsJson');
      if (accountsJson == null) {
        print('SavedAccountsService: No saved accounts found');
        return [];
      }

      final List<dynamic> accountsList = jsonDecode(accountsJson);
      print(
        'SavedAccountsService: Found ${accountsList.length} accounts in storage',
      );
      final List<SavedAccount> accounts = [];

      for (final accountData in accountsList) {
        try {
          // Get encrypted password
          final encryptedPassword = await _secureStorage.read(
            key: 'password_${accountData['email']}',
          );

          if (encryptedPassword != null) {
            final account = SavedAccount.fromJson(accountData);
            // Replace password with decrypted one
            accounts.add(
              SavedAccount(
                email: account.email,
                password: encryptedPassword,
                savedAt: account.savedAt,
                firstName: account.firstName,
                lastName: account.lastName,
              ),
            );
            print(
              'SavedAccountsService: Successfully loaded account: ${account.email}',
            );
          } else {
            print(
              'SavedAccountsService: No encrypted password found for: ${accountData['email']}',
            );
          }
        } catch (e) {
          print('Error loading account ${accountData['email']}: $e');
        }
      }

      print('SavedAccountsService: Returning ${accounts.length} accounts');
      return accounts;
    } catch (e) {
      print('Error getting saved accounts: $e');
      return [];
    }
  }

  /// Get the last used account
  Future<SavedAccount?> getLastUsedAccount() async {
    try {
      final lastUsedEmail = _prefs.getString(_lastUsedAccountKey);
      if (lastUsedEmail == null) return null;

      final accounts = await getSavedAccounts();
      return accounts.firstWhere(
        (account) => account.email == lastUsedEmail,
        orElse: () => accounts.first,
      );
    } catch (e) {
      print('Error getting last used account: $e');
      return null;
    }
  }

  /// Remove a saved account
  Future<void> removeAccount(String email) async {
    try {
      final accounts = await getSavedAccounts();
      accounts.removeWhere((account) => account.email == email);

      // Update saved accounts
      final accountsJson = accounts.map((a) => a.toJson()).toList();
      await _prefs.setString(_savedAccountsKey, jsonEncode(accountsJson));

      // Remove encrypted password
      await _secureStorage.delete(key: 'password_$email');

      // Update last used account if it was removed
      final lastUsedEmail = _prefs.getString(_lastUsedAccountKey);
      if (lastUsedEmail == email) {
        if (accounts.isNotEmpty) {
          await _prefs.setString(_lastUsedAccountKey, accounts.first.email);
        } else {
          await _prefs.remove(_lastUsedAccountKey);
        }
      }
    } catch (e) {
      print('Error removing account: $e');
    }
  }

  /// Clear all saved accounts
  Future<void> clearAllAccounts() async {
    try {
      await _prefs.remove(_savedAccountsKey);
      await _prefs.remove(_lastUsedAccountKey);

      // Clear all encrypted passwords
      final accounts = await getSavedAccounts();
      for (final account in accounts) {
        await _secureStorage.delete(key: 'password_${account.email}');
      }
    } catch (e) {
      print('Error clearing all accounts: $e');
    }
  }

  /// Check if an account is saved
  Future<bool> isAccountSaved(String email) async {
    final accounts = await getSavedAccounts();
    return accounts.any((account) => account.email == email);
  }

  /// Get account by email
  Future<SavedAccount?> getAccountByEmail(String email) async {
    final accounts = await getSavedAccounts();
    try {
      return accounts.firstWhere((account) => account.email == email);
    } catch (e) {
      return null;
    }
  }
}
