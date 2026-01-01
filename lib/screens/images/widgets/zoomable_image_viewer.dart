import 'package:flutter/material.dart';
import 'dart:io';

class ZoomableImageViewer extends StatelessWidget {
  final String? imagePath;
  final TransformationController transformController;

  const ZoomableImageViewer({
    super.key,
    required this.imagePath,
    required this.transformController,
  });

  void _handleDoubleTap(TapDownDetails details) {
    final scale = transformController.value.getMaxScaleOnAxis();

    if (scale > 1.0) {
      transformController.value = Matrix4.identity();
    } else {
      final position = details.localPosition;
      const zoomScale = 2.0;

      final matrix = Matrix4.identity()
        ..translate(
          -position.dx * (zoomScale - 1),
          -position.dy * (zoomScale - 1),
        )
        ..scale(zoomScale);

      transformController.value = matrix;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imagePath == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Image not downloaded yet',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Center(
      child: GestureDetector(
        onDoubleTapDown: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: transformController,
          child: SizedBox.expand(
            child: Image.file(File(imagePath!), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
