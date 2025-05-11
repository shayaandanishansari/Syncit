import 'package:flutter/foundation.dart';
import 'sync_service.dart';

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