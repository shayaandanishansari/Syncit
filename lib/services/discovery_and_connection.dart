import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class DiscoveryAndConnection {
  // Singleton pattern
  static final DiscoveryAndConnection _instance = DiscoveryAndConnection._internal();
  factory DiscoveryAndConnection() => _instance;
  DiscoveryAndConnection._internal();

  final int port = 1234;
  final int tcpPort = 1235; // For continuous file sharing

  late String deviceIp;
  late String bcastIp;
  late String deviceName;

  final Map<String, List<String>> ConnectedDevices = {};
  final Map<String, String> DiscoveredDevices = {};

  RawDatagramSocket? udp_socket;
  Timer? _timer;
  final Map<String, Socket> outgoingSockets = {}; // deviceName -> Socket
  final Map<String, Socket> incomingSockets = {}; // deviceName -> Socket
  ServerSocket? tcpServer;

  // Callbacks to notify UI
  void Function()? onDeviceConnected;
  void Function()? onDeviceDiscovered;  // New callback for discovery

  Future<String> getWifiIP() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      if (iface.name.toLowerCase() == 'wi-fi' || iface.name.toLowerCase() == 'wifi') {
        return iface.addresses
            .firstWhere((a) => a.type == InternetAddressType.IPv4)
            .address;
      }
    }
    return '0.0.0.0';
  }

  Future<void> StartBCast() async {
    deviceIp = await getWifiIP();
    final parts = deviceIp.split('.');
    bcastIp = '${parts[0]}.${parts[1]}.${parts[2]}.255';
    deviceName = Platform.localHostname;

    udp_socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );
    udp_socket!.broadcastEnabled = true;

    udp_socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = udp_socket!.receive();
        if (dg == null) return;
        final msg = utf8.decode(dg.data);
        print('[UDP RECEIVED] from ${dg.address.address}: $msg');
        if (!msg.startsWith('DISCOVERY_SYNCIT_')) return;
        final p = msg.split('_');
        final ip = p[2];
        final name = p[3];
        if (ip != deviceIp && !DiscoveredDevices.containsKey(name)) {
          DiscoveredDevices[name] = ip;
          print('[UDP] Added new device: $name ($ip)');
          onDeviceDiscovered?.call();  // Notify UI of new device
        }
      }
    });

    _timer = Timer.periodic(Duration(seconds: 2), (_) {
      final ping = 'DISCOVERY_SYNCIT_${deviceIp}_${deviceName}';
      print('[UDP SENT] to $bcastIp: $ping');
      udp_socket!.send(
        utf8.encode(ping),
        InternetAddress(bcastIp),
        port,
      );
    });
  }

  void StopBCast() {
    _timer?.cancel();
    udp_socket?.close();
    udp_socket = null;
  }

  // Direct connection after discovery
  Future<void> connectToDevice(String deviceID) async {
    final remoteIp = DiscoveredDevices[deviceID];
    if (remoteIp == null) throw Exception('Device not found');
    
    // Only connect if we haven't already
    if (ConnectedDevices.containsKey(deviceID)) {
      print('[FILE SHARING] Already connected to $deviceID');
      return;
    }

    print('[FILE SHARING] Connecting to $remoteIp:$tcpPort');
    final socket = await Socket.connect(remoteIp, tcpPort);
    print('[FILE SHARING] Connected to $remoteIp:$tcpPort');
    
    // Add to connected devices
    ConnectedDevices[deviceID] = [remoteIp];
    outgoingSockets[deviceID] = socket;
    
    // Send our device info to establish bidirectional connection
    final ourInfo = 'CONNECT_${deviceIp}_${deviceName}\n';
    socket.add(utf8.encode(ourInfo));
    await socket.flush();
    
    // Notify UI
    onDeviceConnected?.call();
  }

  // Start a general TCP server for file sharing
  Future<void> startTCPServer() async {
    tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort, shared: true);
    print('[TCP SERVER] Listening on 0.0.0.0:$tcpPort');
    tcpServer!.listen((client) async {
      print('[TCP SERVER] New client: ${client.remoteAddress.address}');
      
      // Handle initial connection info
      final stream = client.asBroadcastStream();
      final reader = utf8.decoder.bind(stream).transform(const LineSplitter());
      
      // Wait for the first line which should be connection info
      final firstLine = await reader.first;
      if (firstLine.startsWith('CONNECT_')) {
        final parts = firstLine.split('_');
        final remoteIp = parts[1];
        final remoteName = parts[2];
        
        // Add to connected devices if not already present
        if (!ConnectedDevices.containsKey(remoteName)) {
          ConnectedDevices[remoteName] = [remoteIp];
          print('[TCP SERVER] Added $remoteName to ConnectedDevices');
          incomingSockets[remoteName] = client;
          onDeviceConnected?.call();
        }
      }

      // Continue with file receiving logic
      await for (final header in reader) {
        print('[TCP SERVER] Received header: $header');
        // Header: action|folderName|relativePath|size
        final parts = header.split('|');
        if (parts.length < 4) {
          print('[TCP SERVER] Invalid header format: $header');
          continue;
        }
        final action = parts[0];
        final folderName = parts[1];
        final relativePath = parts[2];
        final fileSize = int.tryParse(parts[3]) ?? 0;
        
        print('[TCP SERVER] Processing file:');
        print('  Action: $action');
        print('  Folder: $folderName');
        print('  Path: $relativePath');
        print('  Size: $fileSize bytes');

        final localFolderPath = await _getLocalFolderPath(folderName);
        if (localFolderPath == null) {
          print('[TCP SERVER] ERROR: No local folder mapped for "$folderName". Skipping file.');
          continue;
        }
        
        final filePath = path.join(localFolderPath, relativePath);
        print('[TCP SERVER] Target path: $filePath');

        if (action == 'add' || action == 'modify') {
          // Receive file bytes
          final file = File(filePath);
          await file.parent.create(recursive: true);
          final sink = file.openWrite();
          int received = 0;
          print('[TCP SERVER] Starting file receive...');
          
          await for (final chunk in stream) {
            sink.add(chunk);
            received += chunk.length;
            if (received % 1024 == 0) { // Log progress every 1KB
              print('[TCP SERVER] Received ${received}/${fileSize} bytes (${(received/fileSize*100).toStringAsFixed(1)}%)');
            }
            if (received >= fileSize) break;
          }
          
          await sink.close();
          print('[TCP SERVER] File write complete: $filePath');
        } else if (action == 'delete') {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            print('[TCP SERVER] File deleted: $filePath');
          } else {
            print('[TCP SERVER] File to delete not found: $filePath');
          }
        }
      }
    });
  }

  // Send file change to all connected devices
  Future<void> sendFileChange({
    required String action, // 'add', 'modify', 'delete'
    required String folderName,
    required String relativePath,
    String? filePath,
  }) async {
    for (final entry in outgoingSockets.entries) {
      final socket = entry.value;
      // Send header: action|folderName|relativePath|size\n
      int fileSize = 0;
      if ((action == 'add' || action == 'modify') && filePath != null) {
        fileSize = await File(filePath).length();
      }
      final header = '$action|$folderName|$relativePath|$fileSize\n';
      socket.add(utf8.encode(header));
      if ((action == 'add' || action == 'modify') && filePath != null) {
        final file = File(filePath);
        await socket.addStream(file.openRead());
      }
      await socket.flush();
      print('[FILE SHARING] Sent $action for $relativePath to ${entry.key}');
    }
  }

  // Helper to get or create a folder for received files
  Future<String> _getOrCreateFolder(String folderName) async {
    // For now, use a subfolder in the current directory
    final dir = Directory(folderName);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  // Look up the correct local folder path for a given shared folder name
  Future<String?> _getLocalFolderPath(String folderName) async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getString('shared_folders');
    if (foldersJson != null) {
      final List<dynamic> decoded = jsonDecode(foldersJson);
      for (final f in decoded) {
        final map = Map<String, String>.from(f);
        if (map['name'] == folderName) {
          return map['path'];
        }
      }
    }
    return null;
  }
}

void main() async {
  final d = DiscoveryAndConnection();
  await d.StartBCast();
  await d.startTCPServer();
}
