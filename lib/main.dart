import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/landing_page.dart';
import 'screens/dashboard/dashboard_page.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.init();
  // Request notifications permission asynchronously
  notificationService.requestPermissions();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file. Using environment fallbacks. $e");
  }

  // ── session checking ─────────────────────────────────────
  String? savedEmail;
  String? savedName;
  try {
    final prefs = await SharedPreferences.getInstance();
    savedEmail = prefs.getString('user_email');
    savedName = prefs.getString('user_name');
  } catch (e) {
    debugPrint("Error reading session from local storage: $e");
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFF8F6F1),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(MyApp(savedEmail: savedEmail, savedName: savedName));
}

class MyApp extends StatelessWidget {
  final String? savedEmail;
  final String? savedName;
  const MyApp({super.key, this.savedEmail, this.savedName});

  @override
  Widget build(BuildContext context) {
    final hasSession = savedEmail != null && savedEmail!.trim().isNotEmpty;

    return MaterialApp(
      title: 'Sub Manager Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8F6F1),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFD4593A),
          secondary: Color(0xFF6B6B80),
          surface: Color(0xFFF8F6F1),
          error: Color(0xFFDC2626),
          onSurface: Color(0xFF1A1A2E),
          onPrimary: Colors.white,
          outline: Color(0xFFACA8A1),
          outlineVariant: Color(0xFFE8E4DE),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w800),
          bodyLarge: TextStyle(color: Color(0xFF1A1A2E)),
          bodyMedium: TextStyle(color: Color(0xFF6B6B80)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE8E4DE), width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4593A),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFAF9F6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: const TextStyle(color: Color(0xFFACA8A1)),
          labelStyle: const TextStyle(color: Color(0xFF6B6B80)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4593A), width: 1.5),
          ),
        ),
      ),
      home: hasSession
          ? DashboardPage(userName: savedName ?? '', userEmail: savedEmail!)
          : const LandingPage(),
    );
  }
}
