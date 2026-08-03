import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  static void navigateToLogin() {
    if (currentContext != null) {
      Navigator.of(currentContext!).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  static void showSessionExpiredDialog() {
    if (currentContext != null) {
      showDialog(
        context: currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Session Expired'),
            ],
          ),
          content: Text('Your session has expired. Please login again to continue.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                navigateToLogin();
              },
              child: Text('Login Again'),
            ),
          ],
        ),
      );
    }
  }
}