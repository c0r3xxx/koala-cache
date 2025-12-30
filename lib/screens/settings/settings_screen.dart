import 'package:flutter/material.dart';
import 'image_paths/image_paths_screen.dart';
import 'server_address/server_address_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Image Import Paths'),
            subtitle: const Text('Configure where images are stored'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImagePathsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Koala Cache Server'),
            subtitle: const Text('Configure server address and connection'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ServerAddressScreen(),
                ),
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
