import 'package:flutter/material.dart';
import 'image_detail_screen.dart';
import 'image_item.dart';
import 'package:koala_cache/services/data_store.dart';
import 'package:koala_cache/services/image_cache_service.dart';
import 'package:koala_cache/screens/widgets/snackbar.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  List<String> _imageHashes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImageHashes();
  }

  Future<void> _loadImageHashes() async {
    try {
      // First, load from local cache for immediate display
      final dataStore = await DataStore.getInstance();
      final cachedHashes = await dataStore.getAllImageHashes();

      setState(() {
        _imageHashes = cachedHashes;
        _isLoading = false;
      });

      // Then fetch from server in the background and update
      try {
        final serverHashes = await ImageCacheService.fetchAndCacheImageHashes();

        // Update UI with fresh data from server
        setState(() {
          _imageHashes = serverHashes;
        });
      } catch (e) {
        // Server fetch failed, but we already have cached data showing
        debugPrint('Failed to fetch fresh hashes from server: $e');
        if (mounted) {
          AppSnackBar.showWarning(
            context,
            'Failed to refresh from server. Showing cached images.',
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load images: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _loadImageHashes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Images'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshImages,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshImages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_imageHashes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No images available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _imageHashes.length,
      itemBuilder: (context, index) {
        return ImageItem(
          hash: _imageHashes[index],
          onTap: () => _showImageDetail(context, _imageHashes[index]),
        );
      },
    );
  }

  void _showImageDetail(BuildContext context, String hash) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ImageDetailScreen(hash: hash)),
    );
  }
}
