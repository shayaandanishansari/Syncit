import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart' hide FileWatcher;
import 'file_watcher.dart';
import 'discovery_and_connection.dart';

enum SyncStatus {
  idle,
  syncing,
  error,
  paused
}

class SyncError {
  final String message;
  final String? filePath;
  final DateTime timestamp;
  final dynamic originalError;

  SyncError(this.message, {this.filePath, this.originalError}) : timestamp = DateTime.now();
}

class SyncService {
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final Map<String, FileWatcher> _watchers = {};
  final Map<String, String> _syncPairs = {}; // source -> destination mapping
  final Map<String, SyncStatus> _syncStatus = {};
  final List<SyncError> _errors = [];
  bool _isPaused = false;
  
  // Callbacks for UI updates
  void Function(String path, SyncStatus status)? onStatusChanged;
  void Function(SyncError error)? onError;
  void Function(String sourcePath, String destPath)? onSyncComplete;

  DiscoveryAndConnection? discovery;

  void addSyncPair(String sourcePath, String destinationPath) {
    if (!_syncPairs.containsKey(sourcePath)) {
      _syncPairs[sourcePath] = destinationPath;
      _syncStatus[sourcePath] = SyncStatus.idle;
      _startWatching(sourcePath);
      
      // Also watch the destination folder for changes
      if (!_syncPairs.containsKey(destinationPath)) {
        _syncPairs[destinationPath] = sourcePath;
        _syncStatus[destinationPath] = SyncStatus.idle;
        _startWatching(destinationPath);
      }
    }
  }

  void removeSyncPair(String sourcePath) {
    if (_syncPairs.containsKey(sourcePath)) {
      _stopWatching(sourcePath);
      final destPath = _syncPairs[sourcePath];
      _syncPairs.remove(sourcePath);
      _syncStatus.remove(sourcePath);
      
      // Also remove the reverse mapping
      if (destPath != null && _syncPairs.containsKey(destPath)) {
        _stopWatching(destPath);
        _syncPairs.remove(destPath);
        _syncStatus.remove(destPath);
      }
    }
  }

  void pauseSync() {
    _isPaused = true;
    _updateAllStatuses(SyncStatus.paused);
  }

  void resumeSync() {
    _isPaused = false;
    _updateAllStatuses(SyncStatus.idle);
  }

  void _updateAllStatuses(SyncStatus status) {
    for (final path in _syncStatus.keys) {
      _updateStatus(path, status);
    }
  }

  void _updateStatus(String path, SyncStatus status) {
    _syncStatus[path] = status;
    onStatusChanged?.call(path, status);
  }

  void _startWatching(String sourcePath) {
    final watcher = FileWatcher(
      folderName: path.basename(sourcePath),
      folderPath: sourcePath,
    );

    print('[WATCHER] Watching folder: $sourcePath');

    watcher.onFileEvent = (event) {
      if (!_isPaused) {
        _handleFileEvent(event);
      }
    };

    watcher.start_listening();
    _watchers[sourcePath] = watcher;
  }

  void _stopWatching(String sourcePath) {
    final watcher = _watchers[sourcePath];
    if (watcher != null) {
      watcher.close();
      _watchers.remove(sourcePath);
    }
  }

  Future<void> _handleFileEvent(WatchEvent event) async {
    final sourcePath = event.path;
    final sourceDir = path.dirname(sourcePath);
    final destinationPath = _syncPairs[sourceDir];
    
    if (destinationPath == null) return;

    _updateStatus(sourceDir, SyncStatus.syncing);

    final relativePath = path.relative(sourcePath, from: sourceDir);
    final targetPath = path.join(destinationPath, relativePath);

    print('[SYNC] Detected file event: ${event.type} on $sourcePath');

    try {
      switch (event.type) {
        case ChangeType.ADD:
        case ChangeType.MODIFY:
          await _copyFileWithRetry(sourcePath, targetPath);
          print('[SYNC] Local copy done: $sourcePath -> $targetPath');
          if (discovery != null) {
            print('[SYNC] Sending file change to connected devices...');
            await discovery!.sendFileChange(
              action: event.type == ChangeType.ADD ? 'add' : 'modify',
              folderName: path.basename(sourceDir),
              relativePath: relativePath,
              filePath: sourcePath,
            );
            print('[SYNC] File change sent.');
          }
          break;
        case ChangeType.REMOVE:
          await _deleteFileWithRetry(targetPath);
          print('[SYNC] Local delete done: $targetPath');
          if (discovery != null) {
            print('[SYNC] Sending delete command to connected devices...');
            await discovery!.sendFileChange(
              action: 'delete',
              folderName: path.basename(sourceDir),
              relativePath: relativePath,
            );
            print('[SYNC] Delete command sent.');
          }
          break;
      }
      onSyncComplete?.call(sourcePath, targetPath);
    } catch (e) {
      final error = SyncError(
        'Failed to sync file: ${path.basename(sourcePath)}',
        filePath: sourcePath,
        originalError: e,
      );
      _errors.add(error);
      onError?.call(error);
    } finally {
      _updateStatus(sourceDir, SyncStatus.idle);
    }
  }

  Future<void> _copyFileWithRetry(String source, String destination, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final file = File(source);
        if (await file.exists()) {
          final targetFile = File(destination);
          await targetFile.parent.create(recursive: true);
          
          // Check available space
          final fileSize = await file.length();
          final targetDir = targetFile.parent;
          final availableSpace = await _getAvailableSpace(targetDir.path);
          if (availableSpace < fileSize) {
            throw SyncError('Insufficient disk space');
          }

          // Copy with verification
          await file.copy(destination);
          
          // Verify copy
          final sourceHash = await _getFileHash(source);
          final destHash = await _getFileHash(destination);
          if (sourceHash != destHash) {
            throw SyncError('File integrity check failed');
          }
          
          return;
        }
      } catch (e) {
        attempts++;
        if (attempts == maxRetries) rethrow;
        await Future.delayed(Duration(seconds: 1 * attempts));
      }
    }
  }

  Future<int> _getAvailableSpace(String path) async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        r'(Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Root -eq "' + path.substring(0, 2) + r'\"}).Free'
      ]);
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim()) ?? 0;
      }
    } catch (e) {
      print('Error getting available space: $e');
    }
    return 0;
  }

  Future<void> _deleteFileWithRetry(String path, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          return;
        }
      } catch (e) {
        attempts++;
        if (attempts == maxRetries) rethrow;
        await Future.delayed(Duration(seconds: 1 * attempts));
      }
    }
  }

  Future<String> _getFileHash(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    // Simple hash for now - could be replaced with more robust hashing
    return bytes.length.toString();
  }

  Future<void> dispose() async {
    for (final watcher in _watchers.values) {
      await watcher.close();
    }
    _watchers.clear();
    _syncPairs.clear();
    _syncStatus.clear();
    _errors.clear();
  }

  Map<String, String> get syncPairs => Map.unmodifiable(_syncPairs);
  Map<String, SyncStatus> get syncStatus => Map.unmodifiable(_syncStatus);
  List<SyncError> get errors => List.unmodifiable(_errors);
  bool get isPaused => _isPaused;
} 