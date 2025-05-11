// file_watcher.dart

import 'dart:async';
import 'dart:io';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as path;

class FileWatcher {
  final String folderName;
  final String folderPath;
  late StreamSubscription<WatchEvent> _subscription;
  late void Function(WatchEvent) onFileEvent;
  final Set<String> _watchedFiles = {};
  late final DirectoryWatcher _watcher;

  FileWatcher({
    required this.folderName,
    required this.folderPath,
  }) {
    _watcher = DirectoryWatcher(folderPath);
  }

  void start_listening() {
    _subscription = _watcher.events.listen((event) {
      _handleFileEvent(event);
    });
  }

  void _handleFileEvent(WatchEvent event) {
    final filePath = event.path;
    final fileName = path.basename(filePath);

    switch (event.type) {
      case ChangeType.ADD:
        _watchedFiles.add(filePath);
        onFileEvent(event);
        break;
      case ChangeType.MODIFY:
        if (_watchedFiles.contains(filePath)) {
          onFileEvent(event);
        }
        break;
      case ChangeType.REMOVE:
        _watchedFiles.remove(filePath);
        onFileEvent(event);
        break;
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    _watchedFiles.clear();
  }

  Set<String> get watchedFiles => _watchedFiles;
}
