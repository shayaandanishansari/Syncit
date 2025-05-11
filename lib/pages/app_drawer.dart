import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: settings.ribbonColor),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'SyncIt Options',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pushReplacementNamed(context, '/'),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Synced Folders'),
            onTap: () => Navigator.pushReplacementNamed(context, '/folders'),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Connected Devices'),
            onTap: () => Navigator.pushReplacementNamed(context, '/devices'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => Navigator.pushReplacementNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }
} 