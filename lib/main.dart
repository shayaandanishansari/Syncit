import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/sync_service.dart';
import 'package:path/path.dart' as path;
import 'services/discovery_and_connection.dart';

void main() {
  runApp(const SyncItApp());
}

class SyncItApp extends StatelessWidget {
  const SyncItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SyncServiceNotifier(),
      child: MaterialApp(
        title: 'SyncIt',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomePage(),
          '/devices': (context) => const DevicesPage(),
          '/folders': (context) => const FoldersPage(),
          '/settings': (context) => const SettingsPage(),
        },
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.lightBlue),
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = Provider.of<SyncServiceNotifier>(context);
    final syncPairs = syncService.syncPairs.entries.toList();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Welcome Shayaan', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Card(
                color: Colors.grey[200],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Devices', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 16),
                      if (syncPairs.isEmpty)
                        const Center(
                          child: Text('No devices connected yet.\nAdd a device to start syncing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      else
                        ...syncPairs.map((pair) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          color: Colors.grey[400],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(path.basename(pair.value), 
                                    style: const TextStyle(fontSize: 20)),
                                  Text(pair.value, 
                                    style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                              const Icon(Icons.check_circle, color: Colors.white54),
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
                color: Colors.grey[200],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Folders', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 16),
                      if (syncPairs.isEmpty)
                        const Center(
                          child: Text('No folders shared yet.\nAdd a folder to start syncing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      else
                        ...syncPairs.map((pair) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          color: Colors.grey[400],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(path.basename(pair.key), 
                                    style: const TextStyle(fontSize: 20)),
                                  Text(pair.key, 
                                    style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                              const Icon(Icons.folder_open, color: Colors.black54),
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
  String? _currentPin; // For showing PIN on server

  @override
  void initState() {
    super.initState();
    // Show PIN dialog on server when pairing is requested
    _discovery.onShowPin = (pin) {
      setState(() {
        _currentPin = pin;
      });
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Pairing Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter this PIN on the other device:'),
              const SizedBox(height: 16),
              Text(pin, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentPin = null;
                });
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    };
    // Show pairing result on client
    _discovery.onPairingResult = (success, message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    };
    // Start the pairing server
    _discovery.startPairingServer();
  }

  void _removePairedDevice(String deviceName) {
    setState(() {
      _discovery.PairedDevices.remove(deviceName);
    });
  }

  @override
  void dispose() {
    _discovery.StopBCast();
    super.dispose();
  }

  Future<String> _promptForPinDialog() async {
    String enteredPin = '';
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter PIN'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: (value) => enteredPin = value,
          decoration: const InputDecoration(
            labelText: 'PIN',
            hintText: 'Enter the PIN from the other device',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, enteredPin),
            child: const Text('OK'),
          ),
        ],
      ),
    ) ?? '';
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
    });

    try {
      await _discovery.StartBCast();
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Available Devices'),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final devices = _discovery.DiscoveredDevices.entries.toList();
                if (devices.isEmpty) {
                  return const Center(
                    child: Text('Searching for devices...'),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.computer),
                      title: Text(device.key),
                      subtitle: Text(device.value),
                      onTap: () async {
                        // Show progress dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const AlertDialog(
                            content: Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 16),
                                Text('Pairing...'),
                              ],
                            ),
                          ),
                        );
                        try {
                          await _discovery.Pairing(device.key, _promptForPinDialog);
                          if (!mounted) return;
                          setState(() {}); // Update paired devices
                          Navigator.pop(context); // Close progress dialog
                          Navigator.pop(context); // Close discovery dialog
                        } catch (e) {
                          if (!mounted) return;
                          Navigator.pop(context); // Close progress dialog
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _discovery.StopBCast();
                Navigator.pop(context);
                setState(() {
                  _isDiscovering = false;
                });
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      _discovery.StopBCast();
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
    final pairedDevices = _discovery.PairedDevices.entries.toList();
    final discovered = _discovery.DiscoveredDevices;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Connected Devices', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: pairedDevices.isEmpty
          ? Center(
              child: _isDiscovering
                  ? const CircularProgressIndicator()
                  : const Text('No devices added. Click the + button to add one'),
            )
          : ListView.builder(
              itemCount: pairedDevices.length,
              itemBuilder: (context, index) {
                final entry = pairedDevices[index];
                final name = entry.key;
                final ip = entry.value[0];
                final online = discovered.containsValue(ip);
                return ListTile(
                  leading: const Icon(Icons.computer),
                  title: Text(name),
                  subtitle: Text(ip),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: online,
                        onChanged: null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removePairedDevice(name),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isDiscovering ? null : _startDiscovery,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = Provider.of<SyncServiceNotifier>(context);
    final folders = syncService.syncPairs.entries.toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Synced Folders', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: folders.isEmpty
          ? const Center(
              child: Text('No shared folders yet. Use the + button to add one.'),
            )
          : ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final entry = folders[index];
                return ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Icon(Icons.cloud_done, color: Colors.grey),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => syncService.removeSyncPair(entry.key),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Show add folder dialog
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Settings page (to be implemented)'),
      ),
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
