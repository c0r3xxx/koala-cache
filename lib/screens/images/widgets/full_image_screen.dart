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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.hashes[_currentIndex],
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final imagePath = widget.imagePaths[index];

          if (imagePath == null) {
            // Image not downloaded yet
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
            child: InteractiveViewer(
              child: SizedBox.expand(
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
          );
        },
      ),
    );
  }
}
