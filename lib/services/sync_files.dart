import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'data_store.dart';

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
          await _uploadSingleImage(serverUrl, imageFile);
          successCount++;
          print('Uploaded: ${path.basename(imageFile.path)}');
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
    final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'};

    for (final pathString in paths) {
      final entity = Directory(pathString);

      if (await entity.exists()) {
        // List all files in the directory
        await for (final file in entity.list(recursive: true)) {
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
  static Future<void> _uploadSingleImage(
    String serverUrl,
    File imageFile,
  ) async {
    final uri = Uri.parse('$serverUrl/img');

    final request = http.MultipartRequest('POST', uri);

    // Add the image file
    final fileName = path.basename(imageFile.path);
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: fileName,
      ),
    );

    // Send the request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Server returned status ${response.statusCode}: ${response.body}',
      );
    }
  }
}
