import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/data_store.dart';

/// Screen for configuring the Koala Cache server address
class ServerAddressScreen extends StatefulWidget {
  const ServerAddressScreen({super.key});

  @override
  State<ServerAddressScreen> createState() => _ServerAddressScreenState();
}

class _ServerAddressScreenState extends State<ServerAddressScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  DataStore? _dataStore;
  bool _isLoading = true;
  bool _useHttps = false;

  @override
  void initState() {
    super.initState();
    _initDataStore();
    _addressController.addListener(_saveServerConfig);
    _portController.addListener(_saveServerConfig);
  }

  @override
  void dispose() {
    _addressController.removeListener(_saveServerConfig);
    _portController.removeListener(_saveServerConfig);
    _addressController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _initDataStore() async {
    try {
      _dataStore = await DataStore.getInstance();
      await _loadServerConfig();
    } catch (e) {
      _showError('Failed to initialize: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadServerConfig() async {
    if (_dataStore == null) return;

    final address = await _dataStore!.getServerAddress();
    final port = await _dataStore!.getServerPort();
    final useHttps = await _dataStore!.getUseHttps();

    if (mounted) {
      setState(() {
        _addressController.text = address;
        _portController.text = port.toString();
        _useHttps = useHttps;
      });
    }
  }

  Future<void> _saveServerConfig() async {
    if (_dataStore == null) return;

    final address = _addressController.text.trim();
    final portText = _portController.text.trim();

    if (address.isEmpty) {
      return;
    }

    final port = int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      return;
    }

    await _dataStore!.saveServerAddress(address);
    await _dataStore!.saveServerPort(port);
    await _dataStore!.saveUseHttps(_useHttps);
  }

  Future<void> _testConnection() async {
    final address = _addressController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText);

    if (address.isEmpty || port == null) {
      _showError('Please enter a valid server address and port');
      return;
    }

    final protocol = _useHttps ? 'https' : 'http';
    final url = '$protocol://$address:$port';

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    bool success = false;
    String message = '';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      success = response.statusCode >= 200 && response.statusCode < 500;
      message = success
          ? 'Connection successful'
          : 'Server returned error: ${response.statusCode}';
    } catch (e) {
      success = false;
      message = 'Connection failed: ${e.toString()}';
    }

    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Address')),
      body: _isLoading ? _buildLoadingView() : _buildForm(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Server Configuration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Server Address',
                    hintText: 'e.g., localhost or 192.168.1.100',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: 'e.g., 8080',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.network_check),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _useHttps,
                  onChanged: (value) {
                    setState(() => _useHttps = value);
                    _saveServerConfig();
                  },
                  title: const Text('Use HTTPS'),
                  subtitle: const Text('Enable secure connection'),
                  secondary: const Icon(Icons.lock),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.wifi_find),
              label: const Text('Test Connection'),
            ),
          ),
        ),
      ],
    );
  }
}
