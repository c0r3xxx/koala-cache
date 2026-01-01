import 'package:flutter/material.dart';
import 'dart:io';

class FullImageScreen extends StatelessWidget {
  final String imagePath;

  const FullImageScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          imagePath.split('/').last,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}
