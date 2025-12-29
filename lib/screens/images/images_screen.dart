import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/data_store.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  List<String> _imagePaths = [];
  bool _isLoading = true;

  static const List<String> _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'heic',
    'heif',
  ];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    try {
      final dataStore = await DataStore.getInstance();
      final directoryPaths = await dataStore.getSelectedImagePaths();

      // Scan all selected directories for image files
      final allImagePaths = <String>[];
      for (final dirPath in directoryPaths) {
        final images = await _scanDirectoryForImages(dirPath);
        allImagePaths.addAll(images);
      }

      setState(() {
        _imagePaths = allImagePaths;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading images: $e');
      setState(() {
        _imagePaths = [];
        _isLoading = false;
      });
    }
  }

  Future<List<String>> _scanDirectoryForImages(String dirPath) async {
    final imagePaths = <String>[];

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        print('Directory does not exist: $dirPath');
        return imagePaths;
      }

      final entities = await dir.list().toList();

      for (final entity in entities) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (_imageExtensions.contains(extension)) {
            imagePaths.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory $dirPath: $e');
    }

    return imagePaths;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Images'),
        actions: [
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
                    'Add image directories in Settings',
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
