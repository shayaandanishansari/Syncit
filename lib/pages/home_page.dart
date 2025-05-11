import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../services/sync_service.dart';
import '../services/sync_service_notifier.dart';
import '../services/discovery_and_connection.dart';
import '../services/settings_service.dart';
import 'app_drawer.dart';
import 'custom_app_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DiscoveryAndConnection _discovery = DiscoveryAndConnection();

  @override
  void initState() {
    super.initState();
    // Load settings when page opens
    SettingsService().loadSettings();
    // Start the file sharing server
    _discovery.startTCPServer();
  }

  @override
  Widget build(BuildContext context) {
    final syncService = Provider.of<SyncServiceNotifier>(context);
    final settings = Provider.of<SettingsService>(context);
    final syncPairs = syncService.syncPairs.entries.toList();
    final connectedDevices = _discovery.ConnectedDevices.entries.toList();
    
    return Scaffold(
      appBar: const CustomAppBar(title: 'Welcome Shayaan'),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Card(
                color: settings.backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Devices', 
                        style: TextStyle(
                          fontSize: 32,
                          color: settings.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (connectedDevices.isEmpty)
                        Center(
                          child: Text('No devices connected yet.\nAdd a device to start syncing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: settings.textColor.withOpacity(0.6),
                            ),
                          ),
                        )
                      else
                        ...connectedDevices.map((device) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          color: settings.ribbonColor.withOpacity(0.1),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device.key, 
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: settings.textColor,
                                    ),
                                  ),
                                  Text(device.value[0], 
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: settings.textColor.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.computer, 
                                color: settings.ribbonColor.withOpacity(0.7),
                              ),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Card(
                color: settings.backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Folders', 
                        style: TextStyle(
                          fontSize: 32,
                          color: settings.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (syncPairs.isEmpty)
                        Center(
                          child: Text('No folders shared yet.\nAdd a folder to start syncing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: settings.textColor.withOpacity(0.6),
                            ),
                          ),
                        )
                      else
                        ...syncPairs.map((pair) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          color: settings.ribbonColor.withOpacity(0.1),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(path.basename(pair.key), 
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: settings.textColor,
                                    ),
                                  ),
                                  Text(pair.key, 
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: settings.textColor.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.folder_open, 
                                color: settings.ribbonColor.withOpacity(0.7),
                              ),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 