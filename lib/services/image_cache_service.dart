import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'data_store.dart';
import 'http_client.dart';

/// Result struct containing image metadata and widget
class ImageResult {
  final String hash;
  final String? extension;
  final String? owner;
  final String? imageName;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final double? longitude;
  final double? latitude;
  final Widget imageWidget;

  ImageResult({
    required this.hash,
    this.extension,
    this.owner,
    this.imageName,
    this.createdAt,
    this.modifiedAt,
    this.longitude,
    this.latitude,
    required this.imageWidget,
  });
}

/// Service for managing cached images
class ImageCacheService {
  /// Get image by hash, trying local cache first, then server
  /// If fetched from server, saves to local cache
  static Future<ImageResult?> getImageByHash(String hash) async {
    // Try to get from local cache first
    try {
      final localResult = await _getImageByHashFromLocal(hash);
      if (localResult != null) {
        return localResult;
      }
    } catch (e) {
      // Local fetch failed, continue to server fetch
      debugPrint('Failed to get image from local cache: $e');
    }

    // Try to get from server
    final serverResult = await _getImageByHashFromServer(hash);
    if (serverResult == null) {
      return null;
    }

    // Save to local cache
    try {
      await _saveImageToCache(serverResult);
    } catch (e) {
      debugPrint('Failed to save image to cache: $e');
      // Still return the server result even if caching fails
    }

    return serverResult;
  }

  /// Save an image result to local cache
  static Future<void> _saveImageToCache(ImageResult imageResult) async {
    // Get the cache directory
    final cacheDir = await getApplicationCacheDirectory();
    final imagesDir = Directory('${cacheDir.path}/images');

    // Create images directory if it doesn't exist
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Create file path with hash and extension
    final extension = imageResult.extension ?? 'jpg';
    final filePath = '${imagesDir.path}/${imageResult.hash}.$extension';

    // Extract image bytes from the widget
    // Since the widget is Image.memory, we need to get the bytes differently
    // We'll need to re-fetch or store the bytes separately
    // For now, let's get the bytes from the Image.memory widget
    final imageWidget = imageResult.imageWidget as Image;
    final memoryImage = imageWidget.image as MemoryImage;
    final imageBytes = memoryImage.bytes;

    // Write image bytes to file
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);

    // Save metadata to DataStore
    final metadata = {
      'hash': imageResult.hash,
      'extension': imageResult.extension,
      'owner': imageResult.owner,
      'image_name': imageResult.imageName,
      'created_at': imageResult.createdAt?.toIso8601String(),
      'modified_at': imageResult.modifiedAt?.toIso8601String(),
      'longitude': imageResult.longitude,
      'latitude': imageResult.latitude,
    };

    final dataStore = await DataStore.getInstance();
    await dataStore.saveImageMetadata(imageResult.hash, jsonEncode(metadata));
    await dataStore.saveImageHashMapping(imageResult.hash, filePath);
  }

  /// Get image data and metadata by hash
  static Future<ImageResult?> _getImageByHashFromLocal(String hash) async {
    // Get DataStore instance
    final dataStore = await DataStore.getInstance();

    // Get image path for the hash
    final imagePath = await dataStore.getImagePathForHash(hash);
    if (imagePath == null) {
      throw Exception('Image path not found for hash: $hash');
    }

    // Validate that the file exists
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file not found at path: $imagePath');
    }

    // Get metadata JSON
    final metadataJson = await dataStore.getImageMetadata(hash);

    // Parse metadata if available
    Map<String, dynamic>? metadata;
    if (metadataJson != null) {
      metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
    } else {
      throw Exception('Metadata not found for hash: $hash');
    }

    // Create image widget from file
    final imageWidget = Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.broken_image, size: 50);
      },
    );

    return ImageResult(
      hash: hash,
      extension: metadata['extension'] as String,
      owner: metadata['owner'] as String,
      imageName: metadata['image_name'] as String?,
      createdAt: DateTime.parse(metadata['created_at'] as String),
      modifiedAt: DateTime.parse(metadata['modified_at'] as String),
      longitude: metadata['longitude'] != null
          ? (metadata['longitude'] as num).toDouble()
          : null,
      latitude: metadata['latitude'] != null
          ? (metadata['latitude'] as num).toDouble()
          : null,
      imageWidget: imageWidget,
    );
  }

  /// Get image data and metadata by hash from the server
  /// Returns null if the request fails or image cannot be fetched
  static Future<ImageResult?> _getImageByHashFromServer(String hash) async {
    try {
      // Make authenticated GET request to /img/{hash}
      final response = await HttpClient.authenticatedGet('/img/$hash');

      if (response.statusCode != 200) {
        return null;
      }

      // Parse the JSON response
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

      // Extract fields from response
      final String responseHash = jsonData['hash'] as String;
      final String extension = jsonData['extension'] as String;
      final String owner = jsonData['owner'] as String;
      final String? imageName = jsonData['image_name'] as String?;
      final double? longitude = jsonData['longitude'] != null
          ? (jsonData['longitude'] as num).toDouble()
          : null;
      final double? latitude = jsonData['latitude'] != null
          ? (jsonData['latitude'] as num).toDouble()
          : null;
      final DateTime createdAt = DateTime.parse(
        jsonData['created_at'] as String,
      );
      final DateTime modifiedAt = DateTime.parse(
        jsonData['modified_at'] as String,
      );
      final String base64Content = jsonData['content'] as String;

      // Decode base64 image content
      final Uint8List imageBytes = base64Decode(base64Content);

      // Create image widget from bytes
      final imageWidget = Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.broken_image, size: 50);
        },
      );

      // Return the result with metadata and image widget
      return ImageResult(
        hash: responseHash,
        extension: extension,
        owner: owner,
        imageName: imageName,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        longitude: longitude,
        latitude: latitude,
        imageWidget: imageWidget,
      );
    } catch (e) {
      // Return null if any error occurs
      return null;
    }
  }

  /// Fetch image hashes from server and update the DataStore cache
  /// Returns the list of hashes fetched from the server
  static Future<List<String>> fetchAndCacheImageHashes() async {
    try {
      // Fetch hashes from server using HttpClient
      final hashes = await HttpClient.fetchImageHashes();

      // Store the hashes in DataStore
      final dataStore = await DataStore.getInstance();
      await dataStore.saveAllImageHashes(hashes);

      return hashes;
    } catch (e) {
      debugPrint('Failed to fetch and cache image hashes: $e');
      rethrow;
    }
  }
}
