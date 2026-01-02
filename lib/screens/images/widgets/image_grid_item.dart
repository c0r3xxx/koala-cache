import 'package:flutter/material.dart';
import 'dart:io';
import '../images_screen.dart';

class ImageGridItem extends StatefulWidget {
  final ImageItem imageItem;
  final VoidCallback? onTap;
  final VoidCallback onVisible;

  const ImageGridItem({
    super.key,
    required this.imageItem,
    required this.onTap,
    required this.onVisible,
  });

  @override
  State<ImageGridItem> createState() => _ImageGridItemState();
}

class _ImageGridItemState extends State<ImageGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _hasTriggeredDownload = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    if (widget.imageItem.isDownloading) {
      _animationController.repeat(reverse: true);
    }

    // Trigger download when widget is first built (visible)
    _triggerDownloadIfNeeded();
  }

  @override
  void didUpdateWidget(ImageGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageItem.isDownloading && !oldWidget.imageItem.isDownloading) {
      _animationController.repeat(reverse: true);
    } else if (!widget.imageItem.isDownloading &&
        oldWidget.imageItem.isDownloading) {
      _animationController.stop();
    }
  }

  void _triggerDownloadIfNeeded() {
    if (!_hasTriggeredDownload &&
        widget.imageItem.path == null &&
        !widget.imageItem.isDownloading) {
      _hasTriggeredDownload = true;
      // Schedule the callback after the frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onVisible();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.imageItem.path != null) {
      // Image is downloaded and available
      return Image.file(
        File(widget.imageItem.path!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(Icons.broken_image, Colors.grey);
        },
      );
    } else if (widget.imageItem.isDownloading) {
      // Image is currently downloading
      return _buildLoadingPlaceholder();
    } else {
      // Image is missing (not yet downloaded or failed)
      return _buildPlaceholder(Icons.cloud_download, Colors.grey[800]!);
    }
  }

  Widget _buildLoadingPlaceholder() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.grey[900],
          child: Center(
            child: Icon(
              Icons.cloud_download,
              color: Colors.white.withOpacity(_pulseAnimation.value),
              size: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(IconData? icon, Color color) {
    return Container(
      color: color,
      child: Center(child: Icon(icon, color: Colors.white38, size: 32)),
    );
  }
}
