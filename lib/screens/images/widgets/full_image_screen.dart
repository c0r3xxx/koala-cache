import 'package:flutter/material.dart';
import 'dart:io';

class FullImageScreen extends StatefulWidget {
  final List<String?> imagePaths;
  final List<String> hashes;
  final int initialIndex;

  const FullImageScreen({
    super.key,
    required this.imagePaths,
    required this.hashes,
    required this.initialIndex,
  });

  @override
  State<FullImageScreen> createState() => _FullImageScreenState();
}

class _FullImageScreenState extends State<FullImageScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformControllers = {};
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _transformControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _getTransformController(int index) {
    if (!_transformControllers.containsKey(index)) {
      final controller = TransformationController();
      controller.addListener(() {
        final scale = controller.value.getMaxScaleOnAxis();
        setState(() {
          _isZoomed = scale > 1.0;
        });
      });
      _transformControllers[index] = controller;
    }
    return _transformControllers[index]!;
  }

  void _handleDoubleTap(int index, TapDownDetails details) {
    final controller = _getTransformController(index);
    final scale = controller.value.getMaxScaleOnAxis();

    if (scale > 1.0) {
      // Zoom out
      controller.value = Matrix4.identity();
    } else {
      // Zoom in to 2x centered on tap position
      final position = details.localPosition;
      const zoomScale = 2.0;

      // Calculate the transformation to zoom in centered on the tap position
      final matrix = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (zoomScale - 1),
          -position.dy * (zoomScale - 1),
          1.0,
          1.0,
        )
        ..scaleByDouble(zoomScale, zoomScale, 1.0, 1.0);

      controller.value = matrix;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final imagePath = widget.imagePaths[index];

          if (imagePath == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Image not downloaded yet',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: GestureDetector(
              onDoubleTapDown: (details) => _handleDoubleTap(index, details),
              child: InteractiveViewer(
                transformationController: _getTransformController(index),
                child: SizedBox.expand(
                  child: Image.file(File(imagePath), fit: BoxFit.contain),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
