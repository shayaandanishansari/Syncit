import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'app_drawer.dart';
import 'custom_app_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsService _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _settings.loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings'),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Appearance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // Ribbon Color
          ListTile(
            title: const Text('Ribbon Color'),
            subtitle: Container(
              width: 100,
              height: 30,
              decoration: BoxDecoration(
                color: _settings.ribbonColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.color_lens),
              onPressed: () async {
                final Color? picked = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: _settings.ribbonColor,
                        onColorChanged: (color) {
                          _settings.updateRibbonColor(color);
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                );
                if (picked != null) {
                  _settings.updateRibbonColor(picked);
                }
              },
            ),
          ),
          
          // Background Color
          ListTile(
            title: const Text('Background Color'),
            subtitle: Container(
              width: 100,
              height: 30,
              decoration: BoxDecoration(
                color: _settings.backgroundColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.color_lens),
              onPressed: () async {
                final Color? picked = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: _settings.backgroundColor,
                        onColorChanged: (color) {
                          _settings.updateBackgroundColor(color);
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                );
                if (picked != null) {
                  _settings.updateBackgroundColor(picked);
                }
              },
            ),
          ),
          
          // Text Color
          ListTile(
            title: const Text('Text Color'),
            subtitle: Container(
              width: 100,
              height: 30,
              decoration: BoxDecoration(
                color: _settings.textColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.color_lens),
              onPressed: () async {
                final Color? picked = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: _settings.textColor,
                        onColorChanged: (color) {
                          _settings.updateTextColor(color);
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                );
                if (picked != null) {
                  _settings.updateTextColor(picked);
                }
              },
            ),
          ),
          
          const Divider(height: 32),
          const Text('Sync Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // Sync Toggle
          SwitchListTile(
            title: const Text('Enable Sync'),
            subtitle: const Text('Toggle file synchronization'),
            value: _settings.syncEnabled,
            onChanged: (value) {
              _settings.toggleSync(value);
            },
          ),
        ],
      ),
    );
  }
}

// Simple color picker widget
class ColorPicker extends StatelessWidget {
  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Colors.white,
        Colors.black,
        Colors.grey[100]!,
        Colors.grey[200]!,
        Colors.grey[300]!,
        Colors.grey[400]!,
        Colors.grey[500]!,
        Colors.grey[600]!,
        Colors.grey[700]!,
        Colors.grey[800]!,
        Colors.grey[900]!,
        Colors.red,
        Colors.pink,
        Colors.purple,
        Colors.deepPurple,
        Colors.indigo,
        Colors.blue,
        Colors.lightBlue,
        Colors.cyan,
        Colors.teal,
        Colors.green,
        Colors.lightGreen,
        Colors.lime,
        Colors.yellow,
        Colors.amber,
        Colors.orange,
        Colors.deepOrange,
        Colors.brown,
        Colors.blueGrey,
      ].map((color) => GestureDetector(
        onTap: () => onColorChanged(color),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color == Colors.white ? Colors.grey : (pickerColor == color ? Colors.white : Colors.grey),
              width: pickerColor == color ? 3 : 1,
            ),
          ),
        ),
      )).toList(),
    );
  }
} 