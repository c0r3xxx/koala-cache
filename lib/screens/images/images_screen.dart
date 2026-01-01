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

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  List<String> _imagePaths = [];
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
        final cachedImagePaths = <String>[];
        for (final hash in cachedHashes) {
          final imagePath = await imageCacheService.getImagePath(hash);
          if (imagePath != null) {
            cachedImagePaths.add(imagePath);
          }
        }

        setState(() {
          _imagePaths = cachedImagePaths;
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

        final imagePaths = <String>[];
        final missingHashes = <String>[];

        for (final hash in hashes) {
          final hashStr = hash.toString();
          final imagePath = await imageCacheService.getImagePath(hashStr);

          if (imagePath != null) {
            imagePaths.add(imagePath);
          } else {
            missingHashes.add(hashStr);
          }
        }

        setState(() {
          _imagePaths = imagePaths;
          _errorMessage = null;
        });

        if (missingHashes.isNotEmpty) {
          setState(() {
            _downloadingCount = missingHashes.length;
          });

          if (mounted) {
            AppSnackBar.showInfo(
              context,
              'Downloading $_downloadingCount missing image${_downloadingCount != 1 ? 's' : ''}...',
            );
          }

          await _downloadMissingImages(missingHashes, imageCacheService);
        }
      } else {
        throw Exception('Failed to load images: ${response.statusCode}');
      }
    } catch (e) {
      print('Error refreshing from server: $e');
      if (_imagePaths.isEmpty) {
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
    List<String> missingHashes,
    ImageCacheService imageCacheService,
  ) async {
    int downloadedCount = 0;

    for (final hash in missingHashes) {
      try {
        final path = await imageCacheService.downloadImage(hash);

        if (path != null && mounted) {
          setState(() {
            _imagePaths.add(path);
            downloadedCount++;
            _downloadingCount = missingHashes.length - downloadedCount;
          });
        }
      } catch (e) {
        print('Failed to download image $hash: $e');
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
        imageCount: _imagePaths.length,
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

    if (_imagePaths.isEmpty) {
      return EmptyImagesView(downloadingCount: _downloadingCount);
    }

    return ImageGrid(
      imagePaths: _imagePaths,
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
