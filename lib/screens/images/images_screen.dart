import 'package:flutter/material.dart';
import '../../services/data_store.dart';
import '../../services/http_client.dart';
import '../../services/image_cache_service.dart';
import '../../services/permissions_service.dart';
import '../widgets/snackbar.dart';
import 'widgets/images_app_bar.dart';
import 'widgets/error_view.dart';
import 'widgets/empty_images_view.dart';
import 'widgets/image_grid.dart';
import 'widgets/full_image_screen.dart';

class ImageItem {
  final String hash;
  String? path;
  bool isDownloading;

  ImageItem({required this.hash, this.path, this.isDownloading = false});
}

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  List<ImageItem> _imageItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndLoadImages();
  }

  Future<void> _requestPermissionsAndLoadImages() async {
    final hasPermission = await PermissionsService.requestStoragePermission(
      context,
    );
    if (!hasPermission) {
      _setError('Storage permission is required to load images.');
      return;
    }
    await _loadImages();
  }

  Future<void> _loadImages() async {
    _setLoadingState();

    try {
      // Load cached hashes first for quick display
      final cachedHashes = await _getCachedHashes();
      if (cachedHashes.isNotEmpty) {
        final imageItems = await _createImageItems(cachedHashes);
        _updateImages(imageItems);
      }

      // Then refresh from server
      await _refreshFromServer();
    } catch (e) {
      print('Error loading images: $e');
      _setError('Failed to load images: ${e.toString()}');
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      final hashStrings = await HttpClient.fetchImageHashes();
      await _saveHashes(hashStrings);
      final imageItems = await _createImageItems(hashStrings);
      _updateImages(imageItems);
    } catch (e) {
      print('Error refreshing from server: $e');
      _handleRefreshError();
    }
  }

  Future<void> _downloadImage(ImageItem item) async {
    if (item.path != null || item.isDownloading) return;

    setState(() => item.isDownloading = true);

    try {
      final imageCacheService = await ImageCacheService.getInstance();
      final path = await imageCacheService.downloadImage(item.hash);

      if (mounted && path != null) {
        setState(() {
          item.path = path;
          item.isDownloading = false;
        });
      }
    } catch (e) {
      print('Failed to download image ${item.hash}: $e');
      if (mounted) {
        setState(() => item.isDownloading = false);
      }
    }
  }

  // Helper methods
  Future<List<String>> _getCachedHashes() async {
    final dataStore = await DataStore.getInstance();
    return await dataStore.getAllImageHashes();
  }

  Future<void> _saveHashes(List<String> hashes) async {
    final dataStore = await DataStore.getInstance();
    await dataStore.saveAllImageHashes(hashes);
  }

  Future<List<ImageItem>> _createImageItems(List<String> hashes) async {
    final imageCacheService = await ImageCacheService.getInstance();
    final imageItems = <ImageItem>[];

    for (final hash in hashes) {
      final imagePath = await imageCacheService.getImagePath(hash);
      imageItems.add(ImageItem(hash: hash, path: imagePath));
    }

    return imageItems;
  }

  void _setLoadingState() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
  }

  void _setError(String message) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  void _updateImages(List<ImageItem> imageItems) {
    setState(() {
      _imageItems = imageItems;
      _errorMessage = null;
      _isLoading = false;
    });
  }

  void _handleRefreshError() {
    if (_imageItems.isEmpty) {
      _setError('Failed to load images from server.');
    } else if (mounted) {
      AppSnackBar.showInfo(
        context,
        'Showing cached images. Unable to refresh from server.',
        action: SnackBarAction(label: 'Retry', onPressed: _loadImages),
      );
    }
  }

  int get _downloadedCount =>
      _imageItems.where((item) => item.path != null).length;

  int get _downloadingCount =>
      _imageItems.where((item) => item.isDownloading).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImagesAppBar(
        onRefresh: _loadImages,
        imageCount: _downloadedCount,
        downloadingCount: _downloadingCount,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorView(errorMessage: _errorMessage!, onRetry: _loadImages);
    }

    if (_imageItems.isEmpty) {
      return const EmptyImagesView(downloadingCount: 0);
    }

    return ImageGrid(
      imageItems: _imageItems,
      onRefresh: _loadImages,
      onImageTap: _showFullImage,
      onImageVisible: _downloadImage,
    );
  }

  void _showFullImage(BuildContext context, String path, String hash) {
    final currentIndex = _imageItems.indexWhere((item) => item.hash == hash);
    if (currentIndex == -1) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullImageScreen(
          imagePaths: _imageItems.map((item) => item.path).toList(),
          hashes: _imageItems.map((item) => item.hash).toList(),
          initialIndex: currentIndex,
          onImageDeleted: _loadImages,
        ),
      ),
    );
  }
}
