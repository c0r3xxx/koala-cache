import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../../../services/data_store.dart';

Future<void> showImageInfoDialog(
  BuildContext context, {
  required String hash,
  required String? imagePath,
}) async {
  try {
    final dataStore = await DataStore.getInstance();
    final metadataJson = await dataStore.getImageMetadata(hash);

    Map<String, dynamic>? metadata;
    if (metadataJson != null) {
      metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
    }

    File? imageFile;
    if (imagePath != null) {
      imageFile = File(imagePath);
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image Information'),
        content: SingleChildScrollView(
          child: _ImageInfoContent(
            hash: hash,
            imagePath: imagePath,
            imageFile: imageFile,
            metadata: metadata,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load image info: $e')));
    }
  }
}

class _ImageInfoContent extends StatelessWidget {
  final String hash;
  final String? imagePath;
  final File? imageFile;
  final Map<String, dynamic>? metadata;

  const _ImageInfoContent({
    required this.hash,
    required this.imagePath,
    required this.imageFile,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoRow(label: 'Hash', value: hash),
        if (imagePath != null) ...[
          const SizedBox(height: 8),
          _InfoRow(label: 'Path', value: imagePath!),
        ],
        if (imageFile != null && imageFile!.existsSync()) ...[
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Size',
            value:
                '${(imageFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
          ),
        ],
        if (metadata != null) ...[
          const Divider(height: 24),
          const Text(
            'Metadata:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...metadata!.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _InfoRow(label: entry.key, value: entry.value.toString()),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
