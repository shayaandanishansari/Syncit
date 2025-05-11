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

  // Callbacks for UI
  void Function(String pin)? onShowPin; // Called to display PIN on server
  void Function(bool success, String message)? onPairingResult; // Called to show result on client

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

  // Start TCP server for pairing requests
  Future<void> startPairingServer() async {
    pairingServer = await ServerSocket.bind(InternetAddress.anyIPv4, pairingPort);
    print('[PAIRING SERVER] Listening on 0.0.0.0:$pairingPort');
    pairingServer!.listen((client) async {
      print('[PAIRING SERVER] New pairing request from \\${client.remoteAddress.address}');
      try {
        final lines = utf8.decoder.bind(client).transform(const LineSplitter());
        final data = await lines.first;
        print('[PAIRING SERVER] Received: $data');
        if (data.startsWith('PAIR_REQ_')) {
          // Step 1: Generate and show PIN
          final pin = (Random().nextInt(900000) + 100000).toString();
          onShowPin?.call(pin); // Show PIN on server UI
          client.writeln('PIN:$pin');
          await client.flush();
          print('[PAIRING SERVER] Sent PIN: $pin');

          // Step 2: Wait for client to send back entered PIN
          final entered = await lines.first;
          print('[PAIRING SERVER] Received entered PIN: $entered');
          if (entered == pin) {
            client.writeln('PAIR_OK');
            await client.flush();
            print('[PAIRING SERVER] Pairing successful!');
          } else {
            client.writeln('PAIR_FAIL');
            await client.flush();
            print('[PAIRING SERVER] Pairing failed: wrong PIN');
          }
        } else {
          client.writeln('PAIR_FAIL');
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

  // Pairing via TCP with PIN entry
  Future<void> Pairing(String deviceID, Future<String> Function() promptForPin) async {
    final remoteIp = DiscoveredDevices[deviceID];
    if (remoteIp == null) throw Exception('Device not found');
    print('[TCP PAIRING] Connecting to $remoteIp:$pairingPort');
    final socket = await Socket.connect(remoteIp, pairingPort).timeout(const Duration(seconds: 5));
    socket.writeln('PAIR_REQ_');
    await socket.flush();
    print('[TCP PAIRING] Sent: PAIR_REQ_');
    final lines = utf8.decoder.bind(socket).transform(const LineSplitter());
    final resp = await lines.first;
    print('[TCP PAIRING] Received: $resp');
    if (!resp.startsWith('PIN:')) {
      await socket.close();
      onPairingResult?.call(false, 'Failed to get PIN from server');
      throw Exception('Failed to get PIN from server');
    }
    final pin = resp.substring(4);
    // Prompt user to enter the PIN shown on the other device
    final enteredPin = await promptForPin();
    socket.writeln(enteredPin);
    await socket.flush();
    print('[TCP PAIRING] Sent entered PIN: $enteredPin');
    final result = await lines.first;
    print('[TCP PAIRING] Received: $result');
    await socket.close();
    if (result == 'PAIR_OK') {
      PairedDevices[deviceID] = [remoteIp, pin];
      onPairingResult?.call(true, 'Pairing successful!');
      print('[TCP PAIRING] Pairing successful!');
    } else {
      onPairingResult?.call(false, 'Pairing failed: wrong PIN');
      print('[TCP PAIRING] Pairing failed: wrong PIN');
      // Fallback: try direct TCP connection
      await SwitchToTCPConnection(deviceID);
    }
  }

  // Fallback: Direct TCP connection
  Future<void> SwitchToTCPConnection(String deviceID) async {
    final info = PairedDevices[deviceID] ?? [DiscoveredDevices[deviceID], ''];
    final ip = info[0];
    if (ip == null) throw Exception('No IP for device');
    tcpSocket = await Socket.connect(ip, tcpPort);
    print('[TCP CONNECT] Connected to $ip:$tcpPort');
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
