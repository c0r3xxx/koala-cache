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
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    // Ensure we have a valid token
    final tokenResult = await _ensureValidToken();
    if (!tokenResult.success) {
      throw Exception('Authentication failed: ${tokenResult.message}');
    }

    final secureDataStore = await SecureDataStore.getInstance();
    final token = await secureDataStore.getToken();

    // Create a prepared request
    final request = http.Request(method, Uri.parse(url));

    // Add authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add any additional headers
    if (headers != null) {
      request.headers.addAll(headers);
    }

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

  /// Make an authenticated GET request
  static Future<http.Response> authenticatedGet(String url) async {
    return await _authenticatedRequest('GET', url);
  }

  /// Test connection to the server
  static Future<ConnectionTestResult> testConnection() async {
    final dataStore = await DataStore.getInstance();
    final address = await dataStore.getServerAddress();
    final port = await dataStore.getServerPort();
    final useHttps = await dataStore.getUseHttps();

    if (address.isEmpty) {
      return ConnectionTestResult(
        success: false,
        message: 'Please enter a valid server address and port',
      );
    }

    final protocol = useHttps ? 'https' : 'http';
    final url = '$protocol://$address:$port/health-auth';

    try {
      final response = await _authenticatedRequest('GET', url);

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
    final port = await dataStore.getServerPort();
    final useHttps = await dataStore.getUseHttps();
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

    final protocol = useHttps ? 'https' : 'http';
    final url = '$protocol://$address:$port/login';

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

  /// Upload an image file to the server with authentication
  static Future<String?> uploadImage(
    String serverUrl,
    String base64Content,
    String fileName,
    String extension,
    DateTime createdAt,
    DateTime modifiedAt,
  ) async {
    final url = '$serverUrl/img';

    // Create JSON payload
    final payload = {
      'content': base64Content,
      'extension': extension,
      'image_name': fileName,
      'created_at': createdAt.toUtc().toIso8601String(),
      'modified_at': modifiedAt.toUtc().toIso8601String(),
    };

    final response = await _authenticatedRequest('POST', url, body: payload);

    if (![200, 201, 409].contains(response.statusCode)) {
      throw Exception(
        'Server returned status ${response.statusCode}: ${response.body}',
      );
    }

    // Parse response to get the hash
    try {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      return responseData['hash'] as String?;
    } catch (e) {
      print('Warning: Could not parse hash from response: $e');
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
