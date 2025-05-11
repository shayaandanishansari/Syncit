import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/sync_service.dart';
import 'app_drawer.dart';
import 'custom_app_bar.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  final List<Map<String, String>> _folders = [];
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getString('shared_folders');
    if (foldersJson != null) {
      final List<dynamic> decoded = jsonDecode(foldersJson);
      setState(() {
        _folders.clear();
        for (final f in decoded) {
          _folders.add(Map<String, String>.from(f));
          _syncService.addSyncPair(f['path'] ?? '', f['name'] ?? '');
        }
      });
    }
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shared_folders', jsonEncode(_folders));
  }

  void _addFolderDialog() async {
    String folderName = '';
    String folderPath = '';
    final folderPathController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Shared Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Shared Folder Name'),
              onChanged: (value) => folderName = value,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: folderPathController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Local Folder Path'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () async {
                    String? selected = await FilePicker.platform.getDirectoryPath();
                    if (selected != null) {
                      folderPath = selected;
                      folderPathController.text = selected;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (folderName.isNotEmpty && folderPath.isNotEmpty) {
                setState(() {
                  _folders.add({'name': folderName, 'path': folderPath});
                  _syncService.addSyncPair(folderPath, folderName);
                });
                await _saveFolders();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _removeFolder(int index) async {
    setState(() {
      final folder = _folders[index];
      _syncService.removeSyncPair(folder['path'] ?? '');
      _folders.removeAt(index);
    });
    await _saveFolders();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Synced Folders'),
      drawer: const AppDrawer(),
      body: _folders.isEmpty
          ? const Center(
              child: Text('No shared folders yet. Use the + button to add one.'),
            )
          : ListView.builder(
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                return ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(folder['name'] ?? ''),
                  subtitle: Text(folder['path'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeFolder(index),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFolderDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
} 