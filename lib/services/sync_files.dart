import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'data_store.dart';
import 'http_client.dart';
import '../config/consts.dart';

class SyncFiles {
  /// Upload images to the backend server
  static Future<void> uploadImages() async {
    try {
      // Get DataStore instance
      final dataStore = await DataStore.getInstance();

      // Get server URL and image paths
      final serverUrl = await dataStore.getServerUrl();
      final imagePaths = await dataStore.getSelectedImagePaths();

      if (imagePaths.isEmpty) {
        print('No images to upload');
        return;
      }

      print('Uploading ${imagePaths.length} image(s) to $serverUrl...');

      // Get all image files from the selected paths
      final imageFiles = await _getImageFiles(imagePaths);

      if (imageFiles.isEmpty) {
        print('No image files found in selected paths');
        return;
      }

      print('Found ${imageFiles.length} image file(s) to upload');

      // Upload each image
      int successCount = 0;
      int failureCount = 0;

      for (final imageFile in imageFiles) {
        try {
          final hash = await _uploadSingleImage(serverUrl, imageFile);
          if (hash != null) {
            // Store the hash to image path mapping
            await dataStore.saveImageHashMapping(hash, imageFile.path);
            print('Uploaded: ${path.basename(imageFile.path)} (hash: $hash)');
          } else {
            print(
              'Uploaded: ${path.basename(imageFile.path)} (no hash returned)',
            );
          }
          successCount++;
        } catch (e) {
          failureCount++;
          print('Failed to upload ${path.basename(imageFile.path)}: $e');
        }
      }

      print('Upload complete: $successCount succeeded, $failureCount failed');
    } catch (e) {
      print('Error uploading images: $e');
      rethrow;
    }
  }

  /// Get all image files from the selected paths
  static Future<List<File>> _getImageFiles(Set<String> paths) async {
    final imageFiles = <File>[];

    for (final pathString in paths) {
      final entity = Directory(pathString);

      if (await entity.exists()) {
        // List all files in the directory
        await for (final file in entity.list()) {
          if (file is File) {
            final extension = path.extension(file.path).toLowerCase();
            if (imageExtensions.contains(extension)) {
              imageFiles.add(file);
            }
          }
        }
      }
    }

    return imageFiles;
  }

  /// Upload a single image file to the server
  static Future<String?> _uploadSingleImage(
    String serverUrl,
    File imageFile,
  ) async {
    final fileName = path.basename(imageFile.path);
    final extension = path.extension(imageFile.path).toLowerCase();

    // Read image file as bytes
    final imageBytes = await imageFile.readAsBytes();

    // Base64 encode the image bytes
    final base64Image = base64Encode(imageBytes);

    // Get file metadata
    final stat = await imageFile.stat();
    final createdAt = stat.changed;
    final modifiedAt = stat.modified;

    // Use authenticated upload from HttpClient and get the response with metadata
    final response = await HttpClient.uploadImage(
      serverUrl,
      base64Image,
      fileName,
      extension,
      createdAt,
      modifiedAt,
    );

    if (response != null) {
      final hash = response['hash'] as String?;

      if (hash != null) {
        // Get DataStore instance
        final dataStore = await DataStore.getInstance();

        // Store the hash to image path mapping
        await dataStore.saveImageHashMapping(hash, imageFile.path);

        // Store the metadata as JSON
        final metadataJson = jsonEncode(response);
        await dataStore.saveImageMetadata(hash, metadataJson);

        return hash;
      }
    }

    return null;
  }
}
