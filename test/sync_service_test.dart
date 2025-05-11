import 'package:flutter_test/flutter_test.dart';
import 'package:syncit/services/sync_service.dart';
import 'package:syncit/services/discovery_and_connection.dart';

void main() {
  late SyncService syncService;
  late DiscoveryAndConnection discovery;

  setUp(() {
    syncService = SyncService();
    discovery = DiscoveryAndConnection();
    syncService.discovery = discovery;
  });

  tearDown(() {
    syncService.dispose();
  });

  group('SyncService Tests', () {
    test('addSyncPair should add a new sync pair', () {
      syncService.addSyncPair('/test/path', 'test_device');
      expect(syncService.syncPairs['/test/path'], 'test_device');
    });

    test('removeSyncPair should remove an existing sync pair', () {
      syncService.addSyncPair('/test/path', 'test_device');
      syncService.removeSyncPair('/test/path');
      expect(syncService.syncPairs.containsKey('/test/path'), false);
    });

    test('syncPairs should be empty initially', () {
      expect(syncService.syncPairs.isEmpty, true);
    });

    test('multiple sync pairs can be added', () {
      syncService.addSyncPair('/test/path1', 'device1');
      syncService.addSyncPair('/test/path2', 'device2');
      expect(syncService.syncPairs.length, 2);
      expect(syncService.syncPairs['/test/path1'], 'device1');
      expect(syncService.syncPairs['/test/path2'], 'device2');
    });
  });
} 