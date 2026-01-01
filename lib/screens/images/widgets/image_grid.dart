import 'package:flutter/material.dart';
import '../images_screen.dart';
import 'image_grid_item.dart';

class ImageGrid extends StatelessWidget {
  final List<ImageItem> imageItems;
  final Future<void> Function() onRefresh;
  final void Function(BuildContext, String, String) onImageTap;

  const ImageGrid({
    super.key,
    required this.imageItems,
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
        itemCount: imageItems.length,
        itemBuilder: (context, index) {
          final item = imageItems[index];
          return ImageGridItem(
            imageItem: item,
            onTap: item.path != null
                ? () => onImageTap(context, item.path!, item.hash)
                : null,
          );
        },
      ),
    );
  }
}
