import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/app_selection_screen.dart';
import 'screens/settings_screen.dart';
import 'services/storage_service.dart';

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
      home: const AppEntry(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/pin_setup': (_) => const PinSetupScreen(),
        '/app_selection': (_) => const AppSelectionScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

/// Entry point that routes to PIN setup or home based on PIN state.
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _isLoading = true;
  bool _hasPinSet = false;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    try {
      final isPinSet = await StorageService.isPinSet();
      if (mounted) {
        setState(() {
          _hasPinSet = isPinSet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    if (!_hasPinSet) {
      return const PinSetupScreen();
    }

    return const HomeScreen();
  }
}
