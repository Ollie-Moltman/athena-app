import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/settings_service.dart';
import 'services/history_service.dart';
import 'ui/screens/scan_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/settings_screen.dart';

late SettingsService settingsService;
late HistoryService historyService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences init error: $e — using in-memory fallback');
  }
  // Pass null if SharedPreferences failed — services handle this gracefully
  // with hardcoded defaults and no-op writes (history not persisted in this case).
  settingsService = SettingsService(prefs);
  historyService = HistoryService(prefs);

  runApp(const AthenaApp());
}

class AthenaApp extends StatelessWidget {
  const AthenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Athena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF1A1A2E),
          error: Color(0xFFEF4444),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const ScanScreen(),
        '/history': (_) => const HistoryScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}