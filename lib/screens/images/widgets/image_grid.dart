import 'package:flutter/material.dart';
import 'image_grid_item.dart';

class ImageGrid extends StatelessWidget {
  final List<String> imagePaths;
  final Future<void> Function() onRefresh;
  final void Function(BuildContext, String) onImageTap;

  const ImageGrid({
    super.key,
    required this.imagePaths,
    required this.onRefresh,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          final path = imagePaths[index];
          return ImageGridItem(
            imagePath: path,
            onTap: () => onImageTap(context, path),
          );
        },
      ),
    );
  }
}
