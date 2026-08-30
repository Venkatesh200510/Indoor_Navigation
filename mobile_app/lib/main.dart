import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/scan_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const IndoorNavApp());
}

class IndoorNavApp extends StatelessWidget {
  const IndoorNavApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indoor Navigator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const ScanScreen(),
    );
  }
}
