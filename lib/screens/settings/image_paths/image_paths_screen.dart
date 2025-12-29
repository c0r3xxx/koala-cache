import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/data_store.dart';

class ImagePathsScreen extends StatefulWidget {
  const ImagePathsScreen({super.key});

  @override
  State<ImagePathsScreen> createState() => _ImagePathsScreenState();
}

class _ImagePathsScreenState extends State<ImagePathsScreen> {
  List<DirectoryInfo> _directories = [];
  bool _isLoading = true;
  Set<String> _selectedPaths = {};
  late DataStore _dataStore;
  int _scannedCount = 0;

  @override
  void initState() {
    super.initState();
    _initDataStore();
  }

  Future<void> _initDataStore() async {
    _dataStore = await DataStore.getInstance();
    await _loadSelectedPaths();
    _scanForImageDirectories();
  }

  Future<void> _loadSelectedPaths() async {
    final paths = await _dataStore.getSelectedImagePaths();
    setState(() {
      _selectedPaths = paths;
    });
  }

  Future<void> _saveSelectedPaths() async {
    await _dataStore.saveSelectedImagePaths(_selectedPaths);
  }

  Future<void> _scanForImageDirectories() async {
    setState(() {
      _isLoading = true;
      _directories = [];
      _scannedCount = 0;
    });

    // Request storage permissions for Android 13+ (API 33+)
    if (Platform.isAndroid) {
      // Android 13+ (API 33+) requires READ_MEDIA_IMAGES
      final status = await Permission.photos.request();

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Media access permission is required to scan image directories',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    try {
      // Get common storage directories
      List<Directory> searchDirs = [];

      if (Platform.isAndroid) {
        // Common Android paths
        final externalStorage = Directory('/storage/emulated/0');
        if (await externalStorage.exists()) {
          searchDirs.add(externalStorage);
        }
      } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        // Get user directories
        try {
          final homeDir =
              Platform.environment['HOME'] ??
              Platform.environment['USERPROFILE'];
          if (homeDir != null) {
            searchDirs.add(Directory(homeDir));
          }
        } catch (e) {
          // Fallback to documents directory
          final docsDir = await getApplicationDocumentsDirectory();
          searchDirs.add(docsDir.parent);
        }
      }

      // Scan directories recursively with progressive updates
      for (final dir in searchDirs) {
        await _scanDirectoryAsync(dir, 0, 3); // Max depth of 3
      }

      // Sort by image count (descending)
      setState(() {
        _directories.sort((a, b) => b.imageCount.compareTo(a.imageCount));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning directories: $e')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _scanDirectoryAsync(
    Directory dir,
    int currentDepth,
    int maxDepth,
  ) async {
    if (currentDepth > maxDepth) return;

    try {
      // Use await with a small delay to allow UI updates
      await Future.delayed(Duration.zero);

      final entities = await dir.list().toList();
      int imageCount = 0;

      for (final entity in entities) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if ([
            'jpg',
            'jpeg',
            'png',
            'gif',
            'bmp',
            'webp',
            'heic',
            'heif',
          ].contains(extension)) {
            imageCount++;
          }
        }
      }

      // Update UI progressively with found directories
      if (imageCount > 0) {
        setState(() {
          _directories.add(
            DirectoryInfo(path: dir.path, imageCount: imageCount),
          );
          _scannedCount++;
        });
      }

      // Process subdirectories in batches to avoid blocking
      final subdirs = entities.whereType<Directory>().toList();
      for (int i = 0; i < subdirs.length; i++) {
        final entity = subdirs[i];

        // Skip hidden directories and common exclusions
        final dirName = entity.path.split('/').last;
        if (!dirName.startsWith('.') &&
            ![
              'node_modules',
              'build',
              '.git',
              'cache',
              'Android',
              'AppData',
            ].contains(dirName)) {
          await _scanDirectoryAsync(entity, currentDepth + 1, maxDepth);
        }

        // Yield to UI thread every 5 directories
        if (i % 5 == 0) {
          await Future.delayed(Duration.zero);
        }
      }
    } catch (e) {
      // Skip directories we can't access
    }
  }

  void _togglePath(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
    _saveSelectedPaths();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Import Paths'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanForImageDirectories,
            tooltip: 'Rescan directories',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Scanning for image directories...'),
                  const SizedBox(height: 8),
                  Text(
                    'Found $_scannedCount directories',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            )
          : _directories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No directories with images found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _scanForImageDirectories,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan Again'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _directories.length,
                    itemBuilder: (context, index) {
                      final dirInfo = _directories[index];
                      final isSelected = _selectedPaths.contains(dirInfo.path);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _togglePath(dirInfo.path),
                          secondary: const Icon(Icons.folder),
                          title: Text(
                            dirInfo.path.split('/').last,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dirInfo.path,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${dirInfo.imageCount} image${dirInfo.imageCount != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class DirectoryInfo {
  final String path;
  final int imageCount;

  DirectoryInfo({required this.path, required this.imageCount});
}
