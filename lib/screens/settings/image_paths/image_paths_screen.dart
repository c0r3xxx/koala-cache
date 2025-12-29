import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImagePathsScreen extends StatefulWidget {
  const ImagePathsScreen({super.key});

  @override
  State<ImagePathsScreen> createState() => _ImagePathsScreenState();
}

class _ImagePathsScreenState extends State<ImagePathsScreen> {
  List<DirectoryInfo> _directories = [];
  bool _isLoading = true;
  Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _loadSelectedPaths();
    _scanForImageDirectories();
  }

  Future<void> _loadSelectedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPaths =
          prefs.getStringList('selected_image_paths')?.toSet() ?? {};
    });
  }

  Future<void> _saveSelectedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_image_paths', _selectedPaths.toList());
  }

  Future<void> _scanForImageDirectories() async {
    setState(() {
      _isLoading = true;
    });

    // Request storage permissions
    if (Platform.isAndroid) {
      PermissionStatus status;

      // Android 13+ (API 33+) requires READ_MEDIA_IMAGES
      // Earlier versions use READ_EXTERNAL_STORAGE
      if (await Permission.photos.isGranted ||
          await Permission.storage.isGranted) {
        status = PermissionStatus.granted;
      } else {
        // Try photos permission first (Android 13+)
        status = await Permission.photos.request();

        // If photos permission is not available, try storage permission
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Storage permission is required to scan directories',
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

    List<DirectoryInfo> foundDirectories = [];

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

      // Scan directories recursively
      for (final dir in searchDirs) {
        await _scanDirectory(dir, foundDirectories, 0, 3); // Max depth of 3
      }

      // Sort by image count (descending)
      foundDirectories.sort((a, b) => b.imageCount.compareTo(a.imageCount));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning directories: $e')),
        );
      }
    }

    setState(() {
      _directories = foundDirectories;
      _isLoading = false;
    });
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<DirectoryInfo> results,
    int currentDepth,
    int maxDepth,
  ) async {
    if (currentDepth > maxDepth) return;

    try {
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

      // Only add directories with images
      if (imageCount > 0) {
        results.add(DirectoryInfo(path: dir.path, imageCount: imageCount));
      }

      // Recursively scan subdirectories
      for (final entity in entities) {
        if (entity is Directory) {
          // Skip hidden directories and common exclusions
          final dirName = entity.path.split('/').last;
          if (!dirName.startsWith('.') &&
              !['node_modules', 'build', '.git', 'cache'].contains(dirName)) {
            await _scanDirectory(entity, results, currentDepth + 1, maxDepth);
          }
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for image directories...'),
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '${_selectedPaths.length} of ${_directories.length} directories selected',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
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
