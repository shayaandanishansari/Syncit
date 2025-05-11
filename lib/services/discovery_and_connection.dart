import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

class DiscoveryAndConnection {
  final int port = 1234;
  final int tcpPort = 1235; // For continuous file sharing

  late String deviceIp;
  late String bcastIp;
  late String deviceName;

  final Map<String, List<String>> ConnectedDevices = {};
  final Map<String, String> DiscoveredDevices = {};

  RawDatagramSocket? udp_socket;
  Timer? _timer;
  Socket? tcpSocket; // Continuous connection for file sharing
  ServerSocket? tcpServer;

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
        print('[UDP RECEIVED] from \\${dg.address.address}: $msg');
        if (!msg.startsWith('DISCOVERY_SYNCIT_')) return;
        final p = msg.split('_');
        final ip = p[2];
        final name = p[3];
        if (ip != deviceIp && !DiscoveredDevices.containsKey(name)) {
          DiscoveredDevices[name] = ip;
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
    print('[FILE SHARING] Connecting to $remoteIp:$tcpPort');
    tcpSocket = await Socket.connect(remoteIp, tcpPort);
    print('[FILE SHARING] Connected to $remoteIp:$tcpPort');
    ConnectedDevices[deviceID] = [remoteIp];
    // You can now use tcpSocket to send/receive files
  }

  // Start a general TCP server for file sharing
  Future<void> startTCPServer() async {
    tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
    print('[TCP SERVER] Listening on 0.0.0.0:$tcpPort');
    tcpServer!.listen((client) {
      print('[TCP SERVER] New client: \\${client.remoteAddress.address}');
      // You can now use 'client' to receive files
    });
  }
}

void main() async {
  final d = DiscoveryAndConnection();
  await d.StartBCast();
  await d.startTCPServer();
}
