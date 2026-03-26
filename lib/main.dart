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
    systemNavigationBarColor: Colors.black,
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
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007AFF), // Samsung Blue
          onPrimary: Colors.white,
          secondary: Color(0xFF007AFF),
          surface: Color(0xFF1C1C1E), // One UI Surface Gray
          onSurface: Colors.white,
          error: Color(0xFFFF453A), // One UI Error Red
        ),
        fontFamily: 'Inter',
        cardTheme: CardTheme(
          color: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 0,
        ),
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
