import 'package:shared_preferences/shared_preferences.dart';

/// DataStore service for managing persistent application data
class DataStore {
  static const String _selectedImagePathsKey = 'selected_image_paths';
  static const String _serverAddressKey = 'server_address';
  static const String _serverPortKey = 'server_port';
  static const String _useHttpsKey = 'use_https';
  static const String _imageHashMappingPrefix = 'image_hash_';

  static DataStore? _instance;
  final SharedPreferences _prefs;

  DataStore._(this._prefs);

  /// Get the singleton instance of DataStore
  static Future<DataStore> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = DataStore._(prefs);
    }
    return _instance!;
  }

  /// Get the list of selected image paths
  Future<Set<String>> getSelectedImagePaths() async {
    final paths = _prefs.getStringList(_selectedImagePathsKey) ?? [];
    return paths.toSet();
  }

  /// Save the list of selected image paths
  Future<bool> saveSelectedImagePaths(Set<String> paths) async {
    return await _prefs.setStringList(_selectedImagePathsKey, paths.toList());
  }

  /// Add a path to the selected image paths
  Future<bool> addImagePath(String path) async {
    final paths = await getSelectedImagePaths();
    paths.add(path);
    return await saveSelectedImagePaths(paths);
  }

  /// Remove a path from the selected image paths
  Future<bool> removeImagePath(String path) async {
    final paths = await getSelectedImagePaths();
    paths.remove(path);
    return await saveSelectedImagePaths(paths);
  }

  /// Clear all selected image paths
  Future<bool> clearImagePaths() async {
    return await _prefs.remove(_selectedImagePathsKey);
  }

  /// Check if a path is selected
  Future<bool> isPathSelected(String path) async {
    final paths = await getSelectedImagePaths();
    return paths.contains(path);
  }

  /// Get the server address
  Future<String> getServerAddress() async {
    return _prefs.getString(_serverAddressKey) ?? 'localhost';
  }

  /// Save the server address
  Future<bool> saveServerAddress(String address) async {
    return await _prefs.setString(_serverAddressKey, address);
  }

  /// Get the server port
  Future<int> getServerPort() async {
    return _prefs.getInt(_serverPortKey) ?? 8080;
  }

  /// Save the server port
  Future<bool> saveServerPort(int port) async {
    return await _prefs.setInt(_serverPortKey, port);
  }

  /// Get whether to use HTTPS
  Future<bool> getUseHttps() async {
    return _prefs.getBool(_useHttpsKey) ?? false;
  }

  /// Save whether to use HTTPS
  Future<bool> saveUseHttps(bool useHttps) async {
    return await _prefs.setBool(_useHttpsKey, useHttps);
  }

  /// Get the full server URL
  Future<String> getServerUrl() async {
    final address = await getServerAddress();
    final port = await getServerPort();
    final useHttps = await getUseHttps();
    final protocol = useHttps ? 'https' : 'http';
    return '$protocol://$address:$port';
  }

  /// Save image hash to path mapping
  Future<bool> saveImageHashMapping(String hash, String imagePath) async {
    return await _prefs.setString('$_imageHashMappingPrefix$hash', imagePath);
  }

  /// Get image path for a given hash
  Future<String?> getImagePathForHash(String hash) async {
    return _prefs.getString('$_imageHashMappingPrefix$hash');
  }

  /// Remove image hash mapping
  Future<bool> removeImageHashMapping(String hash) async {
    return await _prefs.remove('$_imageHashMappingPrefix$hash');
  }

  /// Get all image hash mappings
  Future<Map<String, String>> getAllImageHashMappings() async {
    final Map<String, String> mappings = {};
    final keys = _prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_imageHashMappingPrefix)) {
        final hash = key.substring(_imageHashMappingPrefix.length);
        final path = _prefs.getString(key);
        if (path != null) {
          mappings[hash] = path;
        }
      }
    }

    return mappings;
  }
}
