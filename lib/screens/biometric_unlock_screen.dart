import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({Key? key}) : super(key: key);

  @override
  _BiometricUnlockScreenState createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    final biometricService = BiometricService();
    final authenticated = await biometricService.authenticate(
      localizedReason: 'Please authenticate to unlock DutyHours',
    );
    if (authenticated) {
      if (mounted) {
        Navigator.of(context).replace(
          oldRoute: ModalRoute.of(context)!,
          newRoute: MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 80, color: AppTheme.accentOrange),
            ),
            const SizedBox(height: 32),
            const Text(
              'App Locked', 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 12),
            const Text(
              'Use your fingerprint to unlock',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _authenticate,
              icon: const Icon(Icons.fingerprint, size: 28),
              label: const Text('Unlock Now', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await AuthService().logout();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              child: const Text('Logout instead'),
            )
          ],
        ),
      ),
    );
  }
}
