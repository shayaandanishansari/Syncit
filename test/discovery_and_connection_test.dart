import 'package:flutter_test/flutter_test.dart';
import 'package:syncit/services/discovery_and_connection.dart';

void main() {
  late DiscoveryAndConnection discovery;

  setUp(() {
    discovery = DiscoveryAndConnection();
  });

  tearDown(() {
    discovery.StopBCast();
  });

  group('DiscoveryAndConnection Tests', () {
    test('ConnectedDevices should be empty initially', () {
      expect(discovery.ConnectedDevices.isEmpty, true);
    });

    test('DiscoveredDevices should be empty initially', () {
      expect(discovery.DiscoveredDevices.isEmpty, true);
    });

    test('addConnectedDevice should add a device to ConnectedDevices', () {
      discovery.addConnectedDevice('test_device', ['192.168.1.1']);
      expect(discovery.ConnectedDevices.containsKey('test_device'), true);
      expect(discovery.ConnectedDevices['test_device'], ['192.168.1.1']);
    });

    test('addDiscoveredDevice should add a device to DiscoveredDevices', () {
      discovery.addDiscoveredDevice('test_device', '192.168.1.1');
      expect(discovery.DiscoveredDevices.containsKey('test_device'), true);
      expect(discovery.DiscoveredDevices['test_device'], '192.168.1.1');
    });

    test('removeConnectedDevice should remove a device from ConnectedDevices', () {
      discovery.addConnectedDevice('test_device', ['192.168.1.1']);
      discovery.removeConnectedDevice('test_device');
      expect(discovery.ConnectedDevices.containsKey('test_device'), false);
    });
  });
} 