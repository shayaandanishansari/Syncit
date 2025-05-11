import 'package:flutter/material.dart';
import '../services/discovery_and_connection.dart';
import 'app_drawer.dart';
import 'custom_app_bar.dart';

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