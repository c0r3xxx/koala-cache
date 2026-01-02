import 'package:flutter/material.dart';
import 'package:koala_cache/services/image_cache_service.dart';

/// Widget that lazily loads an image when it becomes visible
class ImageItem extends StatefulWidget {
  final String hash;
  final VoidCallback? onTap;

  const ImageItem({super.key, required this.hash, this.onTap});

  @override
  State<ImageItem> createState() => _ImageItemState();
}

class _ImageItemState extends State<ImageItem> {
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
