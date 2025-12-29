import 'package:flutter/material.dart';

class ImagePathsScreen extends StatefulWidget {
  const ImagePathsScreen({super.key});

  @override
  State<ImagePathsScreen> createState() => _ImagePathsScreenState();
}

class _ImagePathsScreenState extends State<ImagePathsScreen> {
  // Sample list of image paths - in a real app, this would be stored in shared preferences or a database
  List<String> imagePaths = [
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/DCIM/Camera',
    '/storage/emulated/0/Download',
  ];

  void _addNewPath() {
    showDialog(
      context: context,
      builder: (context) {
        String newPath = '';
        return AlertDialog(
          title: const Text('Add Image Path'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Path',
              hintText: '/path/to/images',
            ),
            onChanged: (value) {
              newPath = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newPath.isNotEmpty) {
                  setState(() {
                    imagePaths.add(newPath);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removePath(int index) {
    setState(() {
      imagePaths.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Import Paths'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewPath,
            tooltip: 'Add new path',
          ),
        ],
      ),
      body: imagePaths.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No image paths configured',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: imagePaths.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(imagePaths[index]),
                    subtitle: const Text('Tap to browse'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removePath(index),
                      tooltip: 'Remove path',
                    ),
                    onTap: () {
                      // In a real app, this would open a file picker or show images from this path
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening: ${imagePaths[index]}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewPath,
        tooltip: 'Add path',
        child: const Icon(Icons.add),
      ),
    );
  }
}
