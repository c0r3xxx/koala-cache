import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Koala Cache',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Selected: $_selectedIndex')),
      bottomNavigationBar: SizedBox(
        height: 80,
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.image, size: 20),
              label: 'Images',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_document, size: 20),
              label: 'Documents',
            ),
            NavigationDestination(
              icon: Icon(Icons.light, size: 20),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings, size: 20),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
