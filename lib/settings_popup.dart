// settings_popup.dart
import 'package:flutter/material.dart';

class SettingsPopup extends StatefulWidget {
  final Function(double, String, TextAlign) onSettingsChanged;

  // Updated constructor using super parameters
  const SettingsPopup({super.key, required this.onSettingsChanged});

  @override
  SettingsPopupState createState() => SettingsPopupState();
}

class SettingsPopupState extends State<SettingsPopup> {
  double _fontSize = 16.0;
  String _fontFamily = 'Roboto';
  TextAlign _textAlign = TextAlign.left;

  void _applySettings() {
    widget.onSettingsChanged(_fontSize, _fontFamily, _textAlign);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
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
          ListTile(
            title: const Text('Text Alignment'),
            trailing: DropdownButton<TextAlign>(
              value: _textAlign,
              items: TextAlign.values
                  .map((align) => DropdownMenuItem(
                        value: align,
                        child: Text(align.toString().split('.').last),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _textAlign = value!;
                });
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _applySettings,
          child: const Text('Apply'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
