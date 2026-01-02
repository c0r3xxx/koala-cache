import 'package:flutter/material.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../../services/data_store.dart';
import '../../../services/http_client.dart';
import '../../widgets/snackbar.dart';
import 'image_info_dialog.dart';
import 'delete_confirmation_dialog.dart';
import 'zoomable_image_viewer.dart';

class FullImageScreen extends StatefulWidget {
  final List<String?> imagePaths;
  final List<String> hashes;
  final int initialIndex;
  final VoidCallback? onImageDeleted;

  const FullImageScreen({
    super.key,
    required this.imagePaths,
    required this.hashes,
    required this.initialIndex,
    this.onImageDeleted,
  });

  @override
  State<FullImageScreen> createState() => _FullImageScreenState();
}

class _FullImageScreenState extends State<FullImageScreen> {
  late PageController _pageController;
  final Map<int, TransformationController> _transformControllers = {};
  bool _isZoomed = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
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
        final newZoomState = scale > 1.0;
        if (newZoomState != _isZoomed) {
          setState(() => _isZoomed = newZoomState);
        }
      });
      _transformControllers[index] = controller;
    }
    return _transformControllers[index]!;
  }

  String? get _currentImagePath => widget.imagePaths[_currentIndex];
  String get _currentHash => widget.hashes[_currentIndex];

  Future<void> _shareImage() async {
    if (_currentImagePath == null) {
      _showSnackBar('Image not downloaded yet');
      return;
    }

    try {
      await Share.shareXFiles([
        XFile(_currentImagePath!),
      ], text: 'Shared from Koala Cache');
    } catch (e) {
      _showSnackBar('Failed to share image: $e');
    }
  }

  Future<void> _deleteImage() async {
    if (_currentImagePath == null) {
      _showSnackBar('Image not downloaded yet');
      return;
    }

    final confirmed = await showDeleteConfirmationDialog(context);
    if (confirmed != true) return;

    try {
      // Delete from local storage
      final file = File(_currentImagePath!);
      if (await file.exists()) {
        await file.delete();
      }

      final dataStore = await DataStore.getInstance();
      await dataStore.removeImageHashMapping(_currentHash);
      await dataStore.removeImageMetadata(_currentHash);

      // Delete from server (best effort)
      try {
        final response = await HttpClient.authenticatedDelete(
          'img/$_currentHash',
        );
        if (response.statusCode != 200) {
          print(
            'Warning: Server deletion returned status ${response.statusCode}',
          );
        }
      } catch (e) {
        print('Warning: Failed to delete from server: $e');
      }

      if (mounted) {
        _showSnackBar('Image deleted successfully');
        widget.onImageDeleted?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showSnackBar('Failed to delete image: $e');
    }
  }

  void _addToAlbum() {
    _showSnackBar('Add to album feature coming soon!');
  }

  Future<void> _showImageInfo() async {
    await showImageInfoDialog(
      context,
      hash: _currentHash,
      imagePath: _currentImagePath,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    AppSnackBar.showInfo(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _FullImageAppBar(
        onDelete: _deleteImage,
        onAddToAlbum: _addToAlbum,
        onShowInfo: _showImageInfo,
        onShare: _shareImage,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return ZoomableImageViewer(
            imagePath: widget.imagePaths[index],
            transformController: _getTransformController(index),
          );
        },
      ),
    );
  }
}

class _FullImageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onDelete;
  final VoidCallback onAddToAlbum;
  final VoidCallback onShowInfo;
  final VoidCallback onShare;

  const _FullImageAppBar({
    required this.onDelete,
    required this.onAddToAlbum,
    required this.onShowInfo,
    required this.onShare,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
        IconButton(
          icon: const Icon(Icons.album),
          onPressed: onAddToAlbum,
          tooltip: 'Add to Album',
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: onShowInfo,
          tooltip: 'Info',
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: onShare,
          tooltip: 'Share',
        ),
      ],
    );
  }
}
