import 'package:flutter/material.dart';
import 'dart:io';

class FullImageScreen extends StatelessWidget {
  final String imagePath;
  final String hash;

  const FullImageScreen({
    super.key,
    required this.imagePath,
    required this.hash,
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
          child: SizedBox.expand(
            child: Image.file(File(imagePath), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
