import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'v2/app.dart';
export 'v2/app.dart' show PuzzleApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const PuzzleApp());
}
