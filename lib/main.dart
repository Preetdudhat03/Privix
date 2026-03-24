import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/app_selection_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // Dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const PrivixApp());
}

class PrivixApp extends StatelessWidget {
  const PrivixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Privix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00C896),
          surface: Color(0xFF1A1A2E),
          error: Color(0xFFCF6679),
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/app_selection': (_) => const AppSelectionScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
