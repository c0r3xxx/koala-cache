import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/data_store.dart';
import '../../services/http_client.dart';
import '../../services/image_cache_service.dart';
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
  int _downloadingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadingCount = 0;
    });

    try {
      final dataStore = await DataStore.getInstance();
      final imageCacheService = await ImageCacheService.getInstance();

      final cachedHashes = await dataStore.getAllImageHashes();
      if (cachedHashes.isNotEmpty) {
        final imageItems = <ImageItem>[];
        for (final hash in cachedHashes) {
          final imagePath = await imageCacheService.getImagePath(hash);
          imageItems.add(ImageItem(hash: hash, path: imagePath));
        }

        setState(() {
          _imageItems = imageItems;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }

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
      final imageCacheService = await ImageCacheService.getInstance();
      final serverUrl = await dataStore.getServerUrl();
      final url = '$serverUrl/img/hashes';

      final response = await HttpClient.authenticatedGet(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> hashes = jsonResponse['hashes'] ?? [];

        final hashStrings = hashes.map((h) => h.toString()).toList();
        await dataStore.saveAllImageHashes(hashStrings);

        final imageItems = <ImageItem>[];
        final missingIndices = <int>[];

        for (int i = 0; i < hashes.length; i++) {
          final hashStr = hashes[i].toString();
          final imagePath = await imageCacheService.getImagePath(hashStr);

          imageItems.add(ImageItem(hash: hashStr, path: imagePath));

          if (imagePath == null) {
            missingIndices.add(i);
          }
        }

        setState(() {
          _imageItems = imageItems;
          _errorMessage = null;
        });

        if (missingIndices.isNotEmpty) {
          setState(() {
            _downloadingCount = missingIndices.length;
          });

          if (mounted) {
            AppSnackBar.showInfo(
              context,
              'Downloading $_downloadingCount missing image${_downloadingCount != 1 ? 's' : ''}...',
            );
          }

          await _downloadMissingImages(missingIndices, imageCacheService);
        }
      } else {
        throw Exception('Failed to load images: ${response.statusCode}');
      }
    } catch (e) {
      print('Error refreshing from server: $e');
      if (_imageItems.isEmpty) {
        setState(() {
          _errorMessage = 'Failed to load images: ${e.toString()}';
        });
      } else {
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

  Future<void> _downloadMissingImages(
    List<int> missingIndices,
    ImageCacheService imageCacheService,
  ) async {
    int downloadedCount = 0;

    for (final index in missingIndices) {
      if (index >= _imageItems.length) continue;

      final item = _imageItems[index];

      setState(() {
        item.isDownloading = true;
      });

      try {
        final path = await imageCacheService.downloadImage(item.hash);

        if (path != null && mounted) {
          setState(() {
            item.path = path;
            item.isDownloading = false;
            downloadedCount++;
            _downloadingCount = missingIndices.length - downloadedCount;
          });
        }
      } catch (e) {
        print('Failed to download image ${item.hash}: $e');
        if (mounted) {
          setState(() {
            item.isDownloading = false;
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _downloadingCount = 0;
      });

      if (downloadedCount > 0) {
        AppSnackBar.showInfo(
          context,
          'Downloaded $downloadedCount image${downloadedCount != 1 ? 's' : ''}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImagesAppBar(
        onRefresh: _loadImages,
        imageCount: _imageItems.where((item) => item.path != null).length,
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
      return EmptyImagesView(downloadingCount: _downloadingCount);
    }

    return ImageGrid(
      imageItems: _imageItems,
      onRefresh: _loadImages,
      onImageTap: _showFullImage,
    );
  }

  void _showFullImage(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FullImageScreen(imagePath: path)),
    );
  }
}
