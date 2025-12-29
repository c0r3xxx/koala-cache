import 'package:shared_preferences/shared_preferences.dart';

/// DataStore service for managing persistent application data
class DataStore {
  static const String _selectedImagePathsKey = 'selected_image_paths';

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
}
