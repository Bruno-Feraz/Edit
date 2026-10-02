import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/project_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // macOS debug: sandbox off (FFmpeg Process). Il plugin file_picker
  // altrimenti lancia ENTITLEMENT_NOT_FOUND.
  if (Platform.isMacOS) {
    await FilePicker.skipEntitlementsChecks();
  }
  runApp(EditApp(store: ProjectStore()));
}

class EditApp extends StatelessWidget {
  const EditApp({super.key, required this.store});

  final ProjectStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edit',
      debugShowCheckedModeBanner: false,
      theme: EditTheme.dark(),
      themeMode: ThemeMode.dark,
      home: HomeScreen(store: store),
    );
  }
}
