import 'package:flutter/material.dart';

class ImagesScreen extends StatelessWidget {
  const ImagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Images')),
      body: const Center(child: Text('Images Screen')),
    );
  }
}
