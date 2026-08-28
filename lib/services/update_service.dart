import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

class UpdateService {
  static const String _skippedVersionKey = 'skipped_update_version_date';

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // Initialize Upgrader (which checks the Play Store / App Store)
      final upgrader = Upgrader(
        debugDisplayAlways: true, // Set to true to test the dialog UI locally
        durationUntilAlertAgain: const Duration(days: 1),
      );
      
      await upgrader.initialize();
      
      if (upgrader.isUpdateAvailable()) {
        final String latestVersion = upgrader.currentAppStoreVersion ?? 'new';
        final String releaseNotes = upgrader.releaseNotes ?? 'A new version of DutyHours is available on the store.';
        
        // Check if user already skipped this today
        final prefs = await SharedPreferences.getInstance();
        final skippedData = prefs.getString(_skippedVersionKey);
        
        final String today = DateTime.now().toIso8601String().split('T')[0];
        final String currentData = '${latestVersion}_$today';

        if (skippedData != currentData) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, releaseNotes, upgrader, currentData);
          }
        }
      }
    } catch (e) {
      // Silently fail if offline or error occurs
      debugPrint('Update check failed: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, String latestVersion, String releaseNotes, Upgrader upgrader, String currentData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: const RoundedRectangleBorder(), // override app-level orange dialog theme
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF252538) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.6 : 0.25),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.system_update_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Update Available!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Version $latestVersion is ready',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.black26 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        releaseNotes,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString(_skippedVersionKey, currentData);
                              if (context.mounted) Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Maybe Later',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              upgrader.sendUserToAppStore();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Update Now',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
