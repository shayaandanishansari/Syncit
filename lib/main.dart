import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/sync_service.dart';
import 'package:path/path.dart' as path;
import 'services/discovery_and_connection.dart';
import 'services/file_watcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'services/settings_service.dart';
import 'pages/home_page.dart';
import 'pages/devices_page.dart';
import 'pages/folders_page.dart';
import 'pages/settings_page.dart';

void main() {
  // Ensure SyncService is always wired to DiscoveryAndConnection
  SyncService().discovery = DiscoveryAndConnection();
  runApp(const SyncItApp());
}

class SyncItApp extends StatelessWidget {
  const SyncItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncServiceNotifier()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'SyncIt',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: settings.ribbonColor),
              scaffoldBackgroundColor: settings.backgroundColor,
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: settings.textColor,
                displayColor: settings.textColor,
              ),
              useMaterial3: true,
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const HomePage(),
              '/devices': (context) => const DevicesPage(),
              '/folders': (context) => const FoldersPage(),
              '/settings': (context) => const SettingsPage(),
            },
          );
        },
      ),
    );
  }
}

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

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showDrawer;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showDrawer = true,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    return AppBar(
      backgroundColor: settings.ribbonColor,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      iconTheme: const IconThemeData(color: Colors.white),
      automaticallyImplyLeading: showDrawer,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

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

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final DiscoveryAndConnection _discovery = DiscoveryAndConnection();
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    // Start the file sharing server
    _discovery.startTCPServer();
    // Start discovery automatically
    _startDiscovery();
    // Refresh UI when a device connects or is discovered
    _discovery.onDeviceConnected = () {
      if (mounted) setState(() {});
    };
    _discovery.onDeviceDiscovered = () {
      if (mounted) setState(() {});
    };
  }

  void _removeConnectedDevice(String deviceName) {
    setState(() {
      _discovery.ConnectedDevices.remove(deviceName);
    });
  }

  @override
  void dispose() {
    _discovery.StopBCast();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      // Clear existing discovered devices when starting new discovery
      _discovery.DiscoveredDevices.clear();
    });

    try {
      await _discovery.StartBCast();
      if (!mounted) return;
      setState(() {
        _isDiscovering = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error discovering devices: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevices = _discovery.ConnectedDevices.entries.toList();
    final discoveredDevices = _discovery.DiscoveredDevices.entries.toList();
    
    return Scaffold(
      appBar: const CustomAppBar(title: 'Devices'),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Connected Devices Section
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Connected Devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                if (connectedDevices.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No devices connected yet'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: connectedDevices.length,
                      itemBuilder: (context, index) {
                        final entry = connectedDevices[index];
                        final name = entry.key;
                        final ip = entry.value[0];
                        return ListTile(
                          leading: const Icon(Icons.computer),
                          title: Text(name),
                          subtitle: Text(ip),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeConnectedDevice(name),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          // Discovered Devices Section
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Available Devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (_isDiscovering)
                        const CircularProgressIndicator()
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _startDiscovery,
                        ),
                    ],
                  ),
                ),
                if (discoveredDevices.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No devices found. Click refresh to search.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = discoveredDevices[index];
                        final isConnected = connectedDevices.any((e) => e.key == device.key);
                        return ListTile(
                          leading: const Icon(Icons.computer),
                          title: Text(device.key),
                          subtitle: Text(device.value),
                          trailing: isConnected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : TextButton(
                                  onPressed: () async {
                                    try {
                                      await _discovery.connectToDevice(device.key);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Connected to ${device.key}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Connection failed: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Connect'),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  final List<Map<String, String>> _folders = [];
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getString('shared_folders');
    if (foldersJson != null) {
      final List<dynamic> decoded = jsonDecode(foldersJson);
      setState(() {
        _folders.clear();
        for (final f in decoded) {
          _folders.add(Map<String, String>.from(f));
          _syncService.addSyncPair(f['path'] ?? '', f['name'] ?? '');
        }
      });
    }
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shared_folders', jsonEncode(_folders));
  }

  void _addFolderDialog() async {
    String folderName = '';
    String folderPath = '';
    final folderPathController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Shared Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Shared Folder Name'),
              onChanged: (value) => folderName = value,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: folderPathController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Local Folder Path'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () async {
                    String? selected = await FilePicker.platform.getDirectoryPath();
                    if (selected != null) {
                      folderPath = selected;
                      folderPathController.text = selected;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (folderName.isNotEmpty && folderPath.isNotEmpty) {
                setState(() {
                  _folders.add({'name': folderName, 'path': folderPath});
                  _syncService.addSyncPair(folderPath, folderName);
                });
                await _saveFolders();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _removeFolder(int index) async {
    setState(() {
      final folder = _folders[index];
      _syncService.removeSyncPair(folder['path'] ?? '');
      _folders.removeAt(index);
    });
    await _saveFolders();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Synced Folders'),
      drawer: const AppDrawer(),
      body: _folders.isEmpty
          ? const Center(
              child: Text('No shared folders yet. Use the + button to add one.'),
            )
          : ListView.builder(
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                return ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(folder['name'] ?? ''),
                  subtitle: Text(folder['path'] ?? ''),
                  trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeFolder(index),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFolderDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

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

// Provider wrapper for SyncService to allow UI updates
class SyncServiceNotifier extends ChangeNotifier {
  final SyncService _service = SyncService();

  Map<String, String> get syncPairs => _service.syncPairs;

  void addSyncPair(String source, String dest) {
    _service.addSyncPair(source, dest);
    notifyListeners();
  }

  void removeSyncPair(String source) {
    _service.removeSyncPair(source);
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
