import 'package:flutter/material.dart';
import '../../services/data_store.dart';
import '../../services/image_cache_service.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  List<String> _imageHashes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImageHashes();
  }

  Future<void> _loadImageHashes() async {
    try {
      final dataStore = await DataStore.getInstance();
      final hashes = await dataStore.getAllImageHashes();

      setState(() {
        _imageHashes = hashes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load images: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _loadImageHashes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Images'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshImages,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshImages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_imageHashes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No images available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _imageHashes.length,
      itemBuilder: (context, index) {
        return LazyImageItem(
          hash: _imageHashes[index],
          onTap: () => _showImageDetail(context, _imageHashes[index]),
        );
      },
    );
  }

  void _showImageDetail(BuildContext context, String hash) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ImageDetailScreen(hash: hash)),
    );
  }
}

/// Widget that lazily loads an image when it becomes visible
class LazyImageItem extends StatefulWidget {
  final String hash;
  final VoidCallback? onTap;

  const LazyImageItem({super.key, required this.hash, this.onTap});

  @override
  State<LazyImageItem> createState() => _LazyImageItemState();
}

class _LazyImageItemState extends State<LazyImageItem> {
  ImageResult? _imageResult;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_imageResult != null) {
      return _imageResult!.imageWidget;
    }

    if (_hasError) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.broken_image, size: 32, color: Colors.red),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Not loaded yet - trigger load when visible
    // Using a post-frame callback to load after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoading) {
        _loadImage();
      }
    });

    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.image, size: 32, color: Colors.grey),
      ),
    );
  }

  Future<void> _loadImage() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ImageCacheService.getImageByHash(widget.hash);

      if (mounted) {
        setState(() {
          _imageResult = result;
          _isLoading = false;
          _hasError = result == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }
}

/// Detail screen showing full image and metadata
class ImageDetailScreen extends StatelessWidget {
  final String hash;

  const ImageDetailScreen({super.key, required this.hash});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Details')),
      body: FutureBuilder<ImageResult?>(
        future: ImageCacheService.getImageByHash(hash),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load image\n${snapshot.error ?? "Unknown error"}',
                  ),
                ],
              ),
            );
          }

          final imageResult = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full image
                AspectRatio(aspectRatio: 1, child: imageResult.imageWidget),
                // Metadata
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageResult.imageName != null) ...[
                        _buildMetadataRow('Name', imageResult.imageName!),
                        const SizedBox(height: 8),
                      ],
                      _buildMetadataRow('Hash', imageResult.hash),
                      const SizedBox(height: 8),
                      _buildMetadataRow(
                        'Owner',
                        imageResult.owner ?? 'Unknown',
                      ),
                      const SizedBox(height: 8),
                      if (imageResult.createdAt != null) ...[
                        _buildMetadataRow(
                          'Created',
                          _formatDate(imageResult.createdAt!),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (imageResult.modifiedAt != null) ...[
                        _buildMetadataRow(
                          'Modified',
                          _formatDate(imageResult.modifiedAt!),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (imageResult.latitude != null &&
                          imageResult.longitude != null) ...[
                        _buildMetadataRow(
                          'Location',
                          '${imageResult.latitude!.toStringAsFixed(6)}, ${imageResult.longitude!.toStringAsFixed(6)}',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
