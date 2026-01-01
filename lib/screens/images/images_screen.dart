import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../../services/data_store.dart';
import '../../services/sync_files.dart';
import '../../services/http_client.dart';
import '../widgets/snackbar.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  List<String> _imagePaths = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dataStore = await DataStore.getInstance();

      // First, load cached hashes from data store for immediate display
      final cachedHashes = await dataStore.getAllImageHashes();
      if (cachedHashes.isNotEmpty) {
        final cachedImagePaths = <String>[];
        for (final hash in cachedHashes) {
          final imagePath = await dataStore.getImagePathForHash(hash);
          if (imagePath != null && await File(imagePath).exists()) {
            cachedImagePaths.add(imagePath);
          }
        }

        // Show cached images immediately
        setState(() {
          _imagePaths = cachedImagePaths;
          _isLoading = false;
        });
      } else {
        // No cached data, keep loading state
        setState(() {
          _isLoading = false;
        });
      }

      // Then refresh from server in the background
      await _refreshFromServer();
    } catch (e) {
      print('Error loading images: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load images: ${e.toString()}';
      });
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      final dataStore = await DataStore.getInstance();
      final serverUrl = await dataStore.getServerUrl();
      final url = '$serverUrl/img/hashes';

      // Make HTTP request to get image hashes
      final response = await HttpClient.authenticatedGet(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> hashes = jsonResponse['hashes'] ?? [];

        // Store all hashes in data store
        final hashStrings = hashes.map((h) => h.toString()).toList();
        await dataStore.saveAllImageHashes(hashStrings);

        // Resolve hashes to image paths through datastore
        final imagePaths = <String>[];
        for (final hash in hashes) {
          final hashStr = hash.toString();
          final imagePath = await dataStore.getImagePathForHash(hashStr);
          if (imagePath != null && await File(imagePath).exists()) {
            imagePaths.add(imagePath);
          } else {
            print('Image not found for hash: $hashStr');
          }
        }

        setState(() {
          _imagePaths = imagePaths;
          _errorMessage = null;
        });
      } else {
        throw Exception('Failed to load images: ${response.statusCode}');
      }
    } catch (e) {
      print('Error refreshing from server: $e');
      // Don't show error if we already have cached images displayed
      if (_imagePaths.isEmpty) {
        setState(() {
          _errorMessage = 'Failed to load images: ${e.toString()}';
        });
      } else {
        // Show snack bar hint that we're showing cached images
        if (mounted) {
          AppSnackBar.showInfo(
            context,
            'Showing cached images. Unable to refresh from server.',
            action: SnackBarAction(label: 'Retry', onPressed: _loadImages),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Images'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () async {
              await SyncFiles.uploadImages();
            },
            tooltip: 'Upload Images',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadImages,
            tooltip: 'Refresh',
          ),

          if (_imagePaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${_imagePaths.length} images',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadImages,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _imagePaths.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No images found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload images to see them here',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadImages,
              child: GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                ),
                itemCount: _imagePaths.length,
                itemBuilder: (context, index) {
                  final path = _imagePaths[index];
                  return GestureDetector(
                    onTap: () => _showFullImage(context, path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showFullImage(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              path.split('/').last,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          body: Center(child: InteractiveViewer(child: Image.file(File(path)))),
        ),
      ),
    );
  }
}
