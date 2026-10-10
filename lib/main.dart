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
  // One UI edge-to-edge transparent system bars
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const PrivixApp());
}

class PrivixApp extends StatelessWidget {
  const PrivixApp({super.key});

  // Samsung One UI 9 Signature Colors
  static const Color oneUiBlue = Color(0xFF1E6FFE);
  static const Color oneUiBlueLight = Color(0xFF0D6EFD);
  static const Color oneUiGreen = Color(0xFF28C76F);
  static const Color oneUiAmber = Color(0xFFFF9F43);
  static const Color oneUiRed = Color(0xFFFF495C);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Privix',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9), // One UI 9 Light Neutral
        colorScheme: const ColorScheme.light(
          primary: oneUiBlueLight,
          onPrimary: Colors.white,
          secondary: Color(0xFF4C8DFF),
          surface: Colors.white,
          onSurface: Color(0xFF13151A),
          surfaceContainerHighest: Color(0xFFEDF0F5),
          error: oneUiRed,
        ),
        fontFamily: 'Inter',
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return const Color(0xFF8E95A5);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return oneUiBlueLight;
            return const Color(0xFFE2E6EE);
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // AMOLED Pure Black
        colorScheme: const ColorScheme.dark(
          primary: oneUiBlue,
          onPrimary: Colors.white,
          secondary: Color(0xFF3880FF),
          surface: Color(0xFF15161B), // One UI 9 Inset Card Dark
          onSurface: Colors.white,
          surfaceContainerHighest: Color(0xFF22242B),
          error: oneUiRed,
        ),
        fontFamily: 'Inter',
        cardTheme: CardThemeData(
          color: const Color(0xFF15161B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return const Color(0xFF90939E);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return oneUiBlue;
            return const Color(0xFF2D3039);
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
