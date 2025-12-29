import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/data_store.dart';

/// Screen for managing image import paths
class ImagePathsScreen extends StatefulWidget {
  const ImagePathsScreen({super.key});

  @override
  State<ImagePathsScreen> createState() => _ImagePathsScreenState();
}

class _ImagePathsScreenState extends State<ImagePathsScreen> {
  List<DirectoryInfo> _directories = [];
  bool _isLoading = true;
  Set<String> _selectedPaths = {};
  DataStore? _dataStore;
  int _scannedCount = 0;

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

  static const List<String> _excludedDirs = [
    'node_modules',
    'build',
    '.git',
    'cache',
    'Android',
    'AppData',
  ];

  static const int _maxScanDepth = 3;
  static const int _batchSize = 5;

  @override
  void initState() {
    super.initState();
    _initDataStore();
  }

  Future<void> _initDataStore() async {
    try {
      _dataStore = await DataStore.getInstance();
      await _loadSelectedPaths();
      await _scanForImageDirectories();
    } catch (e) {
      _showError('Failed to initialize: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSelectedPaths() async {
    if (_dataStore == null) return;

    final paths = await _dataStore!.getSelectedImagePaths();
    if (mounted) {
      setState(() => _selectedPaths = paths);
    }
  }

  Future<void> _saveSelectedPaths() async {
    if (_dataStore == null) return;
    await _dataStore!.saveSelectedImagePaths(_selectedPaths);
  }

  Future<void> _scanForImageDirectories() async {
    _resetScanState();

    if (Platform.isAndroid && !await _requestPermissions()) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final searchDirs = await _getSearchDirectories();
      await _scanDirectories(searchDirs);
      _sortDirectories();
    } catch (e) {
      _showError('Error scanning directories: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _resetScanState() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _directories = [];
        _scannedCount = 0;
      });
    }
  }

  Future<bool> _requestPermissions() async {
    final status = await Permission.photos.request();

    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Media access permission is required to scan image directories',
          ),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
      return false;
    }

    return status.isGranted;
  }

  Future<List<Directory>> _getSearchDirectories() async {
    if (Platform.isAndroid) {
      return _getAndroidDirectories();
    }
    return _getDesktopDirectories();
  }

  Future<List<Directory>> _getAndroidDirectories() async {
    const externalStoragePath = '/storage/emulated/0';
    final externalStorage = Directory(externalStoragePath);
    return await externalStorage.exists() ? [externalStorage] : [];
  }

  Future<List<Directory>> _getDesktopDirectories() async {
    final homeDir =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

    if (homeDir != null) {
      return [Directory(homeDir)];
    }

    // Fallback to documents directory parent
    final docsDir = await getApplicationDocumentsDirectory();
    return [docsDir.parent];
  }

  Future<void> _scanDirectories(List<Directory> searchDirs) async {
    for (final dir in searchDirs) {
      await _scanDirectoryRecursive(dir, 0);
    }
  }

  Future<void> _scanDirectoryRecursive(Directory dir, int depth) async {
    if (depth > _maxScanDepth) return;

    try {
      await Future.delayed(Duration.zero); // Allow UI updates

      final entities = await dir.list().toList();
      final imageCount = _countImages(entities);

      if (imageCount > 0) {
        _addDirectory(dir.path, imageCount);
      }

      await _scanSubdirectories(entities, depth);
    } catch (e) {
      // Skip inaccessible directories
    }
  }

  int _countImages(List<FileSystemEntity> entities) {
    return entities.whereType<File>().where((file) {
      final extension = file.path.split('.').last.toLowerCase();
      return _imageExtensions.contains(extension);
    }).length;
  }

  void _addDirectory(String path, int imageCount) {
    if (mounted) {
      setState(() {
        _directories.add(DirectoryInfo(path: path, imageCount: imageCount));
        _scannedCount++;
      });
    }
  }

  Future<void> _scanSubdirectories(
    List<FileSystemEntity> entities,
    int currentDepth,
  ) async {
    final subdirs = entities
        .whereType<Directory>()
        .where(_shouldScanDirectory)
        .toList();

    for (int i = 0; i < subdirs.length; i++) {
      await _scanDirectoryRecursive(subdirs[i], currentDepth + 1);

      if (i % _batchSize == 0) {
        await Future.delayed(Duration.zero); // Yield to UI
      }
    }
  }

  bool _shouldScanDirectory(Directory dir) {
    final dirName = dir.path.split('/').last;
    return !dirName.startsWith('.') && !_excludedDirs.contains(dirName);
  }

  void _sortDirectories() {
    if (mounted) {
      setState(() {
        _directories.sort((a, b) => b.imageCount.compareTo(a.imageCount));
      });
    }
  }

  void _togglePath(String path) {
    if (mounted) {
      setState(() {
        if (_selectedPaths.contains(path)) {
          _selectedPaths.remove(path);
        } else {
          _selectedPaths.add(path);
        }
      });
    }
    _saveSelectedPaths();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Image Import Paths'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _scanForImageDirectories,
          tooltip: 'Rescan directories',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingView();
    if (_directories.isEmpty) return _buildEmptyView();
    return _buildDirectoryList();
  }

  Widget _buildLoadingView() {
    return Center(
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
    );
  }

  Widget _buildEmptyView() {
    return Center(
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
    );
  }

  Widget _buildDirectoryList() {
    return ListView.builder(
      itemCount: _directories.length,
      itemBuilder: (context, index) => _buildDirectoryItem(_directories[index]),
    );
  }

  Widget _buildDirectoryItem(DirectoryInfo dirInfo) {
    final isSelected = _selectedPaths.contains(dirInfo.path);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            Text(dirInfo.path, style: const TextStyle(fontSize: 12)),
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
  }
}

/// Represents a directory containing images
@immutable
class DirectoryInfo {
  final String path;
  final int imageCount;

  const DirectoryInfo({required this.path, required this.imageCount});
}
