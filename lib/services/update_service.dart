import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class UpdateService {
  static const String _updateUrl = 'https://raw.githubusercontent.com/railshift/app-updates/main/version.json';
  static const String _skippedVersionKey = 'skipped_update_version_date';

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Fetch remote version info
      final response = await http.get(Uri.parse(_updateUrl));
      if (response.statusCode != 200) {
        return;
      }

      // Sanitize newlines only inside JSON string values (not the structural whitespace)
      final sanitizedBody = response.body.replaceAllMapped(
        RegExp(r'"((?:[^"\\]|\\.)*)"', dotAll: true),
        (match) => '"${match.group(1)!
            .replaceAll('\r\n', '\\n')
            .replaceAll('\n', '\\n')
            .replaceAll('\r', '\\n')
            .replaceAll('\t', '\\t')}"',
      );
      final data = json.decode(sanitizedBody);
      final String latestVersion = data['latest_version'];
      final String updateUrl = data['update_url'];
      final String releaseNotes = data['release_notes'] ?? 'A new version of DutyHours is available.';

      // 2. Get local app version
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 3. Compare versions
      if (_isRemoteGreater(latestVersion, currentVersion)) {
        // 4. Check if user already skipped this today
        final prefs = await SharedPreferences.getInstance();
        final skippedData = prefs.getString(_skippedVersionKey);
        
        final String today = DateTime.now().toIso8601String().split('T')[0];
        final String currentData = '${latestVersion}_$today';

        if (skippedData != currentData) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, releaseNotes, updateUrl, currentData);
          }
        }
      }
    } catch (_) {
      // Silently fail if offline or error occurs
    }
  }

  bool _isRemoteGreater(String remote, String local) {
    try {
      List<int> remoteParts = remote.split('.').map(int.parse).toList();
      List<int> localParts = local.split('.').map(int.parse).toList();
      
      for (int i = 0; i < 3; i++) {
        int r = i < remoteParts.length ? remoteParts[i] : 0;
        int l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _showUpdateDialog(BuildContext context, String latestVersion, String releaseNotes, String updateUrl, String currentData) {
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
                color: Colors.black.withOpacity(isDarkMode ? 0.6 : 0.25),
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
                            onPressed: () async {
                              final url = Uri.parse(updateUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
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
