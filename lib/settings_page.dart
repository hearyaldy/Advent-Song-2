// settings_page.dart
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _fontSize = 16.0;
  String _fontFamily = 'Roboto';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('Font Size'),
            trailing: DropdownButton<double>(
              value: _fontSize,
              items: [14.0, 16.0, 18.0, 20.0]
                  .map((size) => DropdownMenuItem(
                        value: size,
                        child: Text(size.toString()),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _fontSize = value!;
                });
              },
            ),
          ),
          ListTile(
            title: const Text('Font Style'),
            trailing: DropdownButton<String>(
              value: _fontFamily,
              items: ['Roboto', 'Arial', 'Courier']
                  .map((style) => DropdownMenuItem(
                        value: style,
                        child: Text(style),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _fontFamily = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
