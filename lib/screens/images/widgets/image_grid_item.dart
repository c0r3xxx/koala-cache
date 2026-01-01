import 'package:flutter/material.dart';
import 'dart:io';

class ImageGridItem extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;

  const ImageGridItem({
    super.key,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(
                Icons.broken_image,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }
}
