import 'package:flutter/material.dart';

class EmptyImagesView extends StatelessWidget {
  final int downloadingCount;

  const EmptyImagesView({
    super.key,
    required this.downloadingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No images found',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            downloadingCount > 0
                ? 'Downloading $downloadingCount image${downloadingCount != 1 ? 's' : ''}...'
                : 'Upload images to see them here',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
