import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'data_store.dart';
import 'http_client.dart';

/// Model representing image metadata from the server
class ImageMetadata {
  final String hash;
  final String extension;
  final String owner;
  final String? imageName;
  final double? longitude;
  final double? latitude;
  final DateTime createdAt;
  final DateTime modifiedAt;

  ImageMetadata({
    required this.hash,
    required this.extension,
    required this.owner,
    this.imageName,
    this.longitude,
    this.latitude,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory ImageMetadata.fromJson(Map<String, dynamic> json) {
    return ImageMetadata(
      hash: json['hash'] as String,
      extension: json['extension'] as String,
      owner: json['owner'] as String,
      imageName: json['image_name'] as String?,
      longitude: json['longitude'] as double?,
      latitude: json['latitude'] as double?,
      createdAt: DateTime.parse(json['created_at'] as String),
      modifiedAt: DateTime.parse(json['modified_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'extension': extension,
      'owner': owner,
      'image_name': imageName,
      'longitude': longitude,
      'latitude': latitude,
      'created_at': createdAt.toIso8601String(),
      'modified_at': modifiedAt.toIso8601String(),
    };
  }
}

/// Service for managing image cache and downloads
class ImageCacheService {
  static ImageCacheService? _instance;
  final DataStore _dataStore;
  Directory? _cacheDir;

  ImageCacheService._(this._dataStore);

  /// Get the singleton instance of ImageCacheService
  static Future<ImageCacheService> getInstance() async {
    if (_instance == null) {
      final dataStore = await DataStore.getInstance();
      _instance = ImageCacheService._(dataStore);
      await _instance!._initCacheDirectory();
    }
    return _instance!;
  }

  /// Initialize the koala-cache directory
  Future<void> _initCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/koala-cache');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  /// Get the local file path for an image hash
  String _getLocalImagePath(String hash, String extension) {
    // Remove leading dot from extension if present
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return '${_cacheDir!.path}/$hash$ext';
  }

  /// Check if image exists locally or in data store
  Future<String?> getImagePath(String hash) async {
    // First check if we have a mapping in the data store
    final storedPath = await _dataStore.getImagePathForHash(hash);

    if (storedPath != null) {
      // Verify the file still exists
      if (await File(storedPath).exists()) {
        return storedPath;
      } else {
        // File was deleted, remove the mapping
        await _dataStore.removeImageHashMapping(hash);
        await _dataStore.removeImageMetadata(hash);
      }
    }

    return null;
  }

  /// Download image from server if not available locally
  Future<String?> ensureImageAvailable(String hash) async {
    // Check if image already exists locally
    final existingPath = await getImagePath(hash);
    if (existingPath != null) {
      return existingPath;
    }

    // Download from server
    return await downloadImage(hash);
  }

  /// Download an image from the server
  Future<String?> downloadImage(String hash) async {
    try {
      final serverUrl = await _dataStore.getServerUrl();
      final url = '$serverUrl/img/$hash';

      // Make authenticated GET request to download image
      final response = await HttpClient.authenticatedGet(url);

      if (response.statusCode != 200) {
        print('Failed to download image $hash: ${response.statusCode}');
        return null;
      }

      // Parse the JSON response
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final content = jsonResponse['content'] as String;
      final extension = jsonResponse['extension'] as String;

      // Create metadata object
      final metadata = ImageMetadata.fromJson(jsonResponse);

      // Decode base64 content
      final imageBytes = base64Decode(content);

      // Save image to local cache directory
      final localPath = _getLocalImagePath(hash, extension);
      final file = File(localPath);
      await file.writeAsBytes(imageBytes);

      // Save path mapping in data store
      await _dataStore.saveImageHashMapping(hash, localPath);

      // Save metadata in data store
      await _dataStore.saveImageMetadata(hash, jsonEncode(metadata.toJson()));

      print('Successfully downloaded and cached image: $hash');
      return localPath;
    } catch (e) {
      print('Error downloading image $hash: $e');
      return null;
    }
  }

  /// Get metadata for an image hash
  Future<ImageMetadata?> getImageMetadata(String hash) async {
    final metadataJson = await _dataStore.getImageMetadata(hash);
    if (metadataJson == null) return null;

    try {
      final json = jsonDecode(metadataJson) as Map<String, dynamic>;
      return ImageMetadata.fromJson(json);
    } catch (e) {
      print('Error parsing metadata for $hash: $e');
      return null;
    }
  }

  /// Download multiple images in batch
  Future<Map<String, String?>> downloadImagesInBatch(
    List<String> hashes,
  ) async {
    final results = <String, String?>{};

    for (final hash in hashes) {
      final path = await ensureImageAvailable(hash);
      results[hash] = path;
    }

    return results;
  }

  /// Clear the entire image cache
  Future<void> clearCache() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      // Delete all files in cache directory
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }

    // Clear all mappings and metadata from data store
    final mappings = await _dataStore.getAllImageHashMappings();
    for (final hash in mappings.keys) {
      await _dataStore.removeImageHashMapping(hash);
      await _dataStore.removeImageMetadata(hash);
    }
  }

  /// Get cache directory path
  String? getCacheDirectoryPath() {
    return _cacheDir?.path;
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) {
      return 0;
    }

    int totalSize = 0;
    await for (final entity in _cacheDir!.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }
}
