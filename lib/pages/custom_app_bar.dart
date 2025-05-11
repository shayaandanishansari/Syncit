import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showDrawer;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showDrawer = true,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    return AppBar(
      backgroundColor: settings.ribbonColor,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      iconTheme: const IconThemeData(color: Colors.white),
      automaticallyImplyLeading: showDrawer,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 