import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'theme/app_theme.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/navigation_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/biometric_unlock_screen.dart';
import 'services/settings_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print("========================================");
  print("🔔 Handling a background message: ${message.messageId}");
  print("👉 NOTIFICATION TITLE: ${message.notification?.title}");
  print("👉 NOTIFICATION BODY: ${message.notification?.body}");
  print("👉 DATA PAYLOAD: ${message.data}");
  print("========================================");
  
  // The actual notification UI is handled either by the OS (if notification payload is present)
  // or you can call NotificationService here to show a custom local notification.
}

void main() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      print('Firebase initialization failed (missing google-services.json?): $e');
    }

    // Initialize services
    await DatabaseService().initialize();
    await AuthService().initialize();
    await NotificationService().initialize();
    
    runApp(const RailShiftManagerApp());
  }, (error, stackTrace) {
    if (kDebugMode) {
      print('Caught global error: $error');
    }
  }, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      if (!kReleaseMode) {
        parent.print(zone, line);
      }
    },
  ));
}

class RailShiftManagerApp extends StatefulWidget {
  const RailShiftManagerApp({super.key});

  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

  @override
  State<RailShiftManagerApp> createState() => _RailShiftManagerAppState();
}

class _RailShiftManagerAppState extends State<RailShiftManagerApp> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _requiresBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    if (_authService.isAuthenticated) {
      final settingsService = SettingsService();
      _requiresBiometric = await settingsService.getBiometricEnabled();
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: RailShiftManagerApp.isDarkMode,
      builder: (context, darkMode, child) {
        return MaterialApp(
          title: 'DutyHours',
          theme: darkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
          navigatorKey: NavigationService.navigatorKey,
          home: _isLoading 
            ? Scaffold(
                backgroundColor: darkMode ? const Color(0xFF1E1E2C) : Colors.white,
                body: const Center(child: CircularProgressIndicator()),
              )
            : Theme(
                data: Theme.of(context).copyWith(
                  dialogTheme: DialogTheme(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppTheme.accentOrange, width: 1.5),
                    ),
                    backgroundColor: darkMode ? const Color(0xFF252538) : Colors.white,
                    titleTextStyle: TextStyle(
                      color: AppTheme.accentOrange,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    contentTextStyle: TextStyle(
                      color: darkMode ? Colors.white70 : Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentOrange,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                child: _authService.isAuthenticated 
                    ? (_requiresBiometric ? const BiometricUnlockScreen() : const DashboardScreen())
                    : const LoginScreen(),
              ),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/dashboard': (context) => const DashboardScreen(),
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
