import 'package:flutter/material.dart';
import 'dart:io';
import '../images_screen.dart';

class ImageGridItem extends StatelessWidget {
  final ImageItem imageItem;
  final VoidCallback? onTap;

  const ImageGridItem({
    super.key,
    required this.imageItem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (imageItem.path != null) {
      // Image is downloaded and available
      return Image.file(
        File(imageItem.path!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(Icons.broken_image, Colors.grey);
        },
      );
    } else if (imageItem.isDownloading) {
      // Image is currently downloading
      return _buildPlaceholder(null, Colors.grey[300]!, showProgress: true);
    } else {
      // Image is missing (not yet downloaded or failed)
      return _buildPlaceholder(Icons.cloud_download, Colors.grey[400]!);
    }
  }

  Widget _buildPlaceholder(
    IconData? icon,
    Color color, {
    bool showProgress = false,
  }) {
    return Container(
      color: color,
      child: Center(
        child: showProgress
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              )
            : Icon(icon, color: Colors.white70, size: 32),
      ),
    );
  }
}
