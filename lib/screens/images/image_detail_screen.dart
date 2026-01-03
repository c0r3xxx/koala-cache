import 'package:flutter/material.dart';
import 'package:koala_cache/services/image_cache_service.dart';
import 'package:share_plus/share_plus.dart';

/// Detail screen showing full zoomable image
class ImageDetailScreen extends StatefulWidget {
  final String hash;

  const ImageDetailScreen({super.key, required this.hash});

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  final TransformationController _transformationController =
      TransformationController();
  ImageResult? _imageResult;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    // Toggle between zoomed in and zoomed out
    if (_transformationController.value != Matrix4.identity()) {
      // Reset to original size
      _transformationController.value = Matrix4.identity();
    } else {
      // Zoom in to 2x centered on tap position
      final double scale = 2.0;
      final position = details.localPosition;

      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
        ..scale(scale);
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // TODO: Implement delete functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete functionality coming soon')),
      );
    }
  }

  void _handleShowMetaInfo() {
    if (_imageResult == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetaInfoRow('Hash', _imageResult!.hash),
              _buildMetaInfoRow('Extension', _imageResult!.extension ?? 'N/A'),
              _buildMetaInfoRow('Owner', _imageResult!.owner ?? 'N/A'),
              _buildMetaInfoRow('Name', _imageResult!.imageName ?? 'N/A'),
              _buildMetaInfoRow(
                'Created',
                _imageResult!.createdAt?.toString() ?? 'N/A',
              ),
              _buildMetaInfoRow(
                'Modified',
                _imageResult!.modifiedAt?.toString() ?? 'N/A',
              ),
              if (_imageResult!.latitude != null &&
                  _imageResult!.longitude != null)
                _buildMetaInfoRow(
                  'Location',
                  '${_imageResult!.latitude}, ${_imageResult!.longitude}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Future<void> _handleAddToAlbum() async {
    // TODO: Implement album functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Album functionality coming soon')),
    );
  }

  Future<void> _handleShare() async {
    if (_imageResult == null) return;

    try {
      // Get the image file path from cache
      final imageWidget = _imageResult!.imageWidget as Image;

      if (imageWidget.image is FileImage) {
        final fileImage = imageWidget.image as FileImage;
        final file = fileImage.file;

        await Share.shareXFiles([
          XFile(file.path),
        ], text: _imageResult!.imageName ?? 'Shared from Koala Cache');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot share this image')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Image', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<ImageResult?>(
        future: ImageCacheService.getImageByHash(widget.hash),
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
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final imageResult = snapshot.data!;
          _imageResult = imageResult;

          return GestureDetector(
            onDoubleTapDown: (details) => _handleDoubleTap(details),
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: imageResult.imageWidget),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              onTap: _handleDelete,
            ),
            _buildBottomButton(
              icon: Icons.info_outline,
              label: 'Info',
              onTap: _handleShowMetaInfo,
            ),
            _buildBottomButton(
              icon: Icons.photo_album_outlined,
              label: 'Album',
              onTap: _handleAddToAlbum,
            ),
            _buildBottomButton(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: _handleShare,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
