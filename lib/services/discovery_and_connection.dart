import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

class DiscoveryAndConnection {
  final int port = 1234;
  final int tcpPort = 1235;

  late String deviceIp;
  late String bcastIp;
  late String deviceName;

  final Map<String, List<String>> PairedDevices = {};
  final Map<String, String> DiscoveredDevices = {};

  RawDatagramSocket? udp_socket;
  Timer? _timer;
  Socket? tcpSocket;
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

  Future<void> Pairing(String deviceID) async {
    final remoteIp = DiscoveredDevices[deviceID];
    if (remoteIp == null) return;

    final pin = Random().nextInt(900000) + 100000;
    final req = 'PAIR_REQ_${deviceIp}_$pin';
    udp_socket?.send(
      utf8.encode(req),
      InternetAddress(remoteIp),
      port,
    );
    print('[UDP SENT] to $remoteIp: $req');

    await for (final event in udp_socket!) {
      if (event != RawSocketEvent.read) continue;
      final dg = udp_socket!.receive();
      if (dg == null) continue;
      final msg = utf8.decode(dg.data);
      print('[UDP RECEIVED] from \\${dg.address.address}: $msg');
      if (msg == 'PAIR_OK_$pin') {
        PairedDevices[deviceID] = [remoteIp, pin.toString()];
        await SwitchToTCPConnection(deviceID);
        break;
      }
    }
  }

  Future<void> SwitchToTCPConnection(String deviceID) async {
    final info = PairedDevices[deviceID];
    if (info == null) return;
    final ip = info[0];
    tcpSocket = await Socket.connect(ip, tcpPort);
    print('[TCP CONNECT] Connected to $ip:$tcpPort');
  }

  Future<void> startTCPServer() async {
    tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
    print('[TCP SERVER] Listening on 0.0.0.0:$tcpPort');
    tcpServer!.listen((client) {
      print('[TCP SERVER] New client: \\${client.remoteAddress.address}');
    });
  }
}

void main() async {
  final d = DiscoveryAndConnection();
  await d.StartBCast();
}
