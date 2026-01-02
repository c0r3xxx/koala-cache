import 'package:http/http.dart' as http;
import 'dart:convert';
import 'data_store.dart';
import 'secure_data_store.dart';

/// Result of a connection test
class ConnectionTestResult {
  final bool success;
  final String message;

  ConnectionTestResult({required this.success, required this.message});
}

/// HTTP client service for making API requests
class HttpClient {
  /// Make an authenticated HTTP request with JWT bearer token
  static Future<http.Response> _authenticatedRequest(
    String method,
    String path, {
    Object? body,
  }) async {
    // Ensure we have a valid token
    final tokenResult = await _ensureValidToken();
    if (!tokenResult.success) {
      throw Exception('Authentication failed: ${tokenResult.message}');
    }

    final secureDataStore = await SecureDataStore.getInstance();
    final token = await secureDataStore.getToken();

    // Get server URL from data store
    final dataStore = await DataStore.getInstance();
    final serverUrl = await dataStore.getServerUrl();
    final url = '$serverUrl$path';

    // Create a prepared request
    final request = http.Request(method, Uri.parse(url));

    // Add authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add body if provided
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List<int>) {
        request.bodyBytes = body;
      } else if (body is Map<String, dynamic>) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
    }

    // Send the request
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 3),
    );

    // Convert streamed response to regular response
    return await http.Response.fromStream(streamedResponse);
  }

  /// Test connection to the server
  static Future<ConnectionTestResult> testConnection() async {
    final dataStore = await DataStore.getInstance();
    final address = await dataStore.getServerAddress();

    if (address.isEmpty) {
      return ConnectionTestResult(
        success: false,
        message: 'Please enter a valid server address and port',
      );
    }

    try {
      final response = await _authenticatedRequest('GET', '/health-auth');

      final success = response.statusCode == 200;
      final message = success
          ? 'Connection successful'
          : 'Server returned error: ${response.statusCode}';

      return ConnectionTestResult(success: success, message: message);
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        message: 'Connection failed: ${e.toString()}',
      );
    }
  }

  /// Login to the server with stored credentials
  static Future<ConnectionTestResult> login() async {
    final dataStore = await DataStore.getInstance();
    final secureDataStore = await SecureDataStore.getInstance();

    final address = await dataStore.getServerAddress();
    final username = await secureDataStore.getUsername();
    final password = await secureDataStore.getPassword();

    if (address.isEmpty) {
      return ConnectionTestResult(
        success: false,
        message: 'Please enter a valid server address and port',
      );
    }

    if (username.isEmpty || password.isEmpty) {
      return ConnectionTestResult(
        success: false,
        message: 'Please enter username and password',
      );
    }

    final serverUrl = await dataStore.getServerUrl();
    final url = '${serverUrl}login';

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final token = responseData['token'] as String?;

        if (token != null && token.isNotEmpty) {
          await secureDataStore.saveToken(token);
          return ConnectionTestResult(
            success: true,
            message: 'Login successful',
          );
        } else {
          return ConnectionTestResult(
            success: false,
            message: 'Invalid response: token not found',
          );
        }
      } else {
        return ConnectionTestResult(
          success: false,
          message: 'Login failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        message: 'Login failed: ${e.toString()}',
      );
    }
  }

  // generic authnicated get
  static Future<http.Response> authenticatedGet(String path) async {
    return await _authenticatedRequest('GET', path);
  }

  // generic authnicated delete
  static Future<http.Response> authenticatedDelete(String path) async {
    return await _authenticatedRequest('DELETE', path);
  }

  /// Fetch all image hashes from the server
  static Future<List<String>> fetchImageHashes() async {
    final response = await authenticatedGet('img/hashes');

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      final List<dynamic> hashes = jsonResponse['hashes'] ?? [];
      return hashes.map((h) => h.toString()).toList();
    } else {
      throw Exception('Failed to load images: ${response.statusCode}');
    }
  }

  /// Upload an image file to the server with authentication
  static Future<Map<String, dynamic>?> uploadImage(
    String base64Content,
    String fileName,
    String extension,
    DateTime createdAt,
    DateTime modifiedAt,
  ) async {
    // Create JSON payload
    final payload = {
      'content': base64Content,
      'extension': extension,
      'image_name': fileName,
      'created_at': createdAt.toUtc().toIso8601String(),
      'modified_at': modifiedAt.toUtc().toIso8601String(),
    };

    final response = await _authenticatedRequest('POST', '/img', body: payload);

    if (![200, 201, 409].contains(response.statusCode)) {
      throw Exception(
        'Server returned status ${response.statusCode}: ${response.body}',
      );
    }

    // Parse response to get the hash and metadata
    try {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      return responseData;
    } catch (e) {
      print('Warning: Could not parse response: $e');
      return null;
    }
  }

  /// Decode JWT token and check if it's valid for at least one hour
  static bool _isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Decode the payload (second part)
      final payload = parts[1];
      // Add padding if needed
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;

      // Check expiration
      final exp = payloadMap['exp'] as int?;
      if (exp == null) return false;

      final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      final oneHourFromNow = now.add(const Duration(hours: 1));

      // Token must be valid for at least one more hour
      return expirationTime.isAfter(oneHourFromNow);
    } catch (e) {
      return false;
    }
  }

  /// Ensure we have a valid JWT token, login if necessary
  static Future<ConnectionTestResult> _ensureValidToken() async {
    final secureDataStore = await SecureDataStore.getInstance();
    final token = await secureDataStore.getToken();

    // If token exists and is valid, we're good
    if (token.isNotEmpty && _isTokenValid(token)) {
      return ConnectionTestResult(success: true, message: 'Token valid');
    }

    // Otherwise, login to get a new token
    return await login();
  }
}
