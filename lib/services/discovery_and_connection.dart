import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

class DiscoveryAndConnection {
  final int port = 1234;
  final int tcpPort = 1235;
  final int pairingPort = 1236;

  late String deviceIp;
  late String bcastIp;
  late String deviceName;

  final Map<String, List<String>> PairedDevices = {};
  final Map<String, String> DiscoveredDevices = {};

  RawDatagramSocket? udp_socket;
  Timer? _timer;
  Socket? tcpSocket;
  ServerSocket? tcpServer;
  ServerSocket? pairingServer;

  Future<String> getWifiIP() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
    throw Exception('No suitable IPv4 address found. Please check your network connection.');
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

  // Start TCP server for pairing requests
  Future<void> startPairingServer() async {
    pairingServer = await ServerSocket.bind(InternetAddress.anyIPv4, pairingPort);
    print('[PAIRING SERVER] Listening on 0.0.0.0:$pairingPort');
    pairingServer!.listen((client) async {
      print('[PAIRING SERVER] New pairing request from \\${client.remoteAddress.address}');
      try {
        final data = await utf8.decoder.bind(client).first;
        print('[PAIRING SERVER] Received: $data');
        if (data.startsWith('PAIR_REQ_')) {
          // Accept all pair requests for now
          final pin = Random().nextInt(900000) + 100000;
          final resp = 'PAIR_OK_$pin';
          client.write(resp);
          await client.flush();
          print('[PAIRING SERVER] Sent: $resp');
        } else {
          client.write('PAIR_FAIL');
          await client.flush();
          print('[PAIRING SERVER] Sent: PAIR_FAIL');
        }
      } catch (e) {
        print('[PAIRING SERVER] Error: $e');
      } finally {
        await client.close();
      }
    });
  }

  // Pairing via TCP
  Future<void> Pairing(String deviceID) async {
    final remoteIp = DiscoveredDevices[deviceID];
    if (remoteIp == null) throw Exception('Device not found');
    final pin = Random().nextInt(900000) + 100000;
    final req = 'PAIR_REQ_${deviceIp}_$pin';
    print('[TCP PAIRING] Connecting to $remoteIp:$pairingPort');
    final socket = await Socket.connect(remoteIp, pairingPort).timeout(const Duration(seconds: 5));
    socket.write(req);
    await socket.flush();
    print('[TCP PAIRING] Sent: $req');
    final resp = await utf8.decoder.bind(socket).first;
    print('[TCP PAIRING] Received: $resp');
    await socket.close();
    if (resp.startsWith('PAIR_OK_')) {
      PairedDevices[deviceID] = [remoteIp, pin.toString()];
      print('[TCP PAIRING] Pairing successful!');
    } else {
      throw Exception('Pairing failed: $resp');
    }
  }

  // (Optional) Start a general TCP server for further communication
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
  await d.startPairingServer();
}
