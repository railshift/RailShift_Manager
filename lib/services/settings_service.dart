import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keySound = 'sound_enabled';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keyAutoBackup = 'auto_backup_enabled';
  static const String _keyDutyHourLimit = 'duty_hour_limit';
  static const String _keyWarningHours = 'warning_hours';
  static const String _keyLanguage = 'selected_language';
  static const String _keyTheme = 'selected_theme';
  static const String _keyBiometric = 'biometric_enabled';

  // Singleton pattern
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> getNotificationsEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyNotifications) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyNotifications, value);
  }

  Future<bool> getSoundEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keySound) ?? true;
  }

  Future<void> setSoundEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keySound, value);
  }

  Future<bool> getVibrationEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyVibration) ?? true;
  }

  Future<void> setVibrationEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyVibration, value);
  }

  Future<bool> getAutoBackupEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyAutoBackup) ?? true;
  }

  Future<void> setAutoBackupEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyAutoBackup, value);
  }

  Future<int> getDutyHourLimit() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyDutyHourLimit) ?? 9;
  }

  Future<void> setDutyHourLimit(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyDutyHourLimit, value);
  }

  Future<int> getWarningHours() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyWarningHours) ?? 8;
  }

  Future<void> setWarningHours(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyWarningHours, value);
  }

  Future<String> getLanguage() async {
    final prefs = await _prefs;
    return prefs.getString(_keyLanguage) ?? 'English';
  }

  Future<void> setLanguage(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_keyLanguage, value);
  }

  Future<String> getTheme() async {
    final prefs = await _prefs;
    return prefs.getString(_keyTheme) ?? 'System';
  }

  Future<void> setTheme(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_keyTheme, value);
  }

  Future<bool> getBiometricEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyBiometric) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyBiometric, value);
  }
}
