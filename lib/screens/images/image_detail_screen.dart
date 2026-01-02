import 'package:flutter/material.dart';
import 'package:koala_cache/services/image_cache_service.dart';

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
