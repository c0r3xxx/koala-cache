import 'package:flutter/material.dart';
import '../../../services/data_store.dart';
import '../../../services/secure_data_store.dart';
import '../../../services/http_client.dart';

/// Screen for configuring the Koala Cache server address
class ServerAddressScreen extends StatefulWidget {
  const ServerAddressScreen({super.key});

  @override
  State<ServerAddressScreen> createState() => _ServerAddressScreenState();
}

class _ServerAddressScreenState extends State<ServerAddressScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  DataStore? _dataStore;
  SecureDataStore? _secureDataStore;
  bool _isLoading = true;
  bool _useHttps = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initDataStore();
    _addressController.addListener(_saveServerConfig);
    _portController.addListener(_saveServerConfig);
    _usernameController.addListener(_saveCredentials);
    _passwordController.addListener(_saveCredentials);
  }

  @override
  void dispose() {
    _addressController.removeListener(_saveServerConfig);
    _portController.removeListener(_saveServerConfig);
    _usernameController.removeListener(_saveCredentials);
    _passwordController.removeListener(_saveCredentials);
    _addressController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initDataStore() async {
    try {
      _dataStore = await DataStore.getInstance();
      _secureDataStore = await SecureDataStore.getInstance();
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
    if (_dataStore == null || _secureDataStore == null) return;

    final address = await _dataStore!.getServerAddress();
    final port = await _dataStore!.getServerPort();
    final useHttps = await _dataStore!.getUseHttps();
    final username = await _secureDataStore!.getUsername();
    final password = await _secureDataStore!.getPassword();

    if (mounted) {
      setState(() {
        _addressController.text = address;
        _portController.text = port.toString();
        _useHttps = useHttps;
        _usernameController.text = username;
        _passwordController.text = password;
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

  Future<void> _saveCredentials() async {
    if (_secureDataStore == null) return;

    await _secureDataStore!.saveUsername(_usernameController.text.trim());
    await _secureDataStore!.savePassword(_passwordController.text.trim());
  }

  Future<void> _testConnection() async {
    final address = _addressController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText);

    if (address.isEmpty || port == null) {
      _showError('Please enter a valid server address and port');
      return;
    }

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    final result = await HttpClient.testConnection();

    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
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
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
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
