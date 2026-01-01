import 'package:flutter/material.dart';
import '../../../services/sync_files.dart';

class ImagesAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onRefresh;
  final int imageCount;
  final int downloadingCount;

  const ImagesAppBar({
    super.key,
    required this.onRefresh,
    required this.imageCount,
    required this.downloadingCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Images'),
      actions: [
        IconButton(
          icon: const Icon(Icons.cloud_upload),
          onPressed: () async {
            await SyncFiles.uploadImages();
          },
          tooltip: 'Upload Images',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
        if (imageCount > 0 || downloadingCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                '$imageCount images${downloadingCount > 0 ? ' (+$downloadingCount)' : ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
