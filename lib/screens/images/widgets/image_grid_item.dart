import 'package:flutter/material.dart';
import 'dart:io';
import 'package:visibility_detector/visibility_detector.dart';
import '../images_screen.dart';

class ImageGridItem extends StatefulWidget {
  final ImageItem imageItem;
  final VoidCallback? onTap;
  final VoidCallback? onVisible;

  const ImageGridItem({
    super.key,
    required this.imageItem,
    required this.onTap,
    this.onVisible,
  });

  @override
  State<ImageGridItem> createState() => _ImageGridItemState();
}

class _ImageGridItemState extends State<ImageGridItem> {
  bool _hasBeenVisible = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    // Trigger loading when at least 10% of the widget is visible
    if (!_hasBeenVisible && info.visibleFraction > 0.1) {
      _hasBeenVisible = true;
      widget.onVisible?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('image_${widget.imageItem.hash}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: _buildImageWidget(),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (widget.imageItem.path != null) {
      return Image.file(
        File(widget.imageItem.path!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(Icons.broken_image, Colors.grey);
        },
      );
    } else if (widget.imageItem.isDownloading) {
      return _buildLoadingPlaceholder();
    } else {
      return _buildPlaceholder(Icons.image, Colors.grey[800]!);
    }
  }

  Widget _buildPlaceholder(IconData icon, Color color) {
    return Container(
      color: color,
      child: Center(child: Icon(icon, color: Colors.white38, size: 32)),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
        ),
      ),
    );
  }
}
