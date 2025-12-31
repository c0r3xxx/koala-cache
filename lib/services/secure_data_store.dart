import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SecureDataStore service for managing sensitive data like credentials
class SecureDataStore {
  static const String _usernameKey = 'username';
  static const String _passwordKey = 'password';
  static const String _tokenKey = 'jwt_token';

  static SecureDataStore? _instance;
  final FlutterSecureStorage _storage;

  SecureDataStore._(this._storage);

  /// Get the singleton instance of SecureDataStore
  static Future<SecureDataStore> getInstance() async {
    if (_instance == null) {
      const storage = FlutterSecureStorage();
      _instance = SecureDataStore._(storage);
    }
    return _instance!;
  }

  /// Get the username
  Future<String> getUsername() async {
    return await _storage.read(key: _usernameKey) ?? '';
  }

  /// Save the username
  Future<void> saveUsername(String username) async {
    if (username.isEmpty) {
      await _storage.delete(key: _usernameKey);
    } else {
      await _storage.write(key: _usernameKey, value: username);
    }
    // Clear JWT token when username changes
    await _storage.delete(key: _tokenKey);
  }

  /// Get the password
  Future<String> getPassword() async {
    return await _storage.read(key: _passwordKey) ?? '';
  }

  /// Save the password
  Future<void> savePassword(String password) async {
    if (password.isEmpty) {
      await _storage.delete(key: _passwordKey);
    } else {
      await _storage.write(key: _passwordKey, value: password);
    }
    // Clear JWT token when password changes
    await _storage.delete(key: _tokenKey);
  }

  /// Clear all stored credentials
  Future<void> clearCredentials() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }

  /// Check if credentials are stored
  Future<bool> hasCredentials() async {
    final username = await getUsername();
    final password = await getPassword();
    return username.isNotEmpty && password.isNotEmpty;
  }

  /// Get the JWT token
  Future<String> getToken() async {
    return await _storage.read(key: _tokenKey) ?? '';
  }

  /// Save the JWT token
  Future<void> saveToken(String token) async {
    if (token.isEmpty) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  /// Clear the JWT token
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Check if token is stored
  Future<bool> hasToken() async {
    final token = await getToken();
    return token.isNotEmpty;
  }
}
