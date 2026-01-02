import 'package:flutter/material.dart';
import 'package:koala_cache/services/image_cache_service.dart';

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
    );
  }
}
