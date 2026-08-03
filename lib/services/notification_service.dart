import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import '../models/duty_assignment.dart';
import '../models/alert.dart';
import '../services/navigation_service.dart';
import '../services/shift_service.dart';
import '../screens/duty_detail_screen.dart';
import '../screens/alert_management_screen.dart';
import '../screens/alert_detail_screen.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final ShiftService _shiftService = ShiftService();
  final AuthService _authService = AuthService();
  static const String _sentDutyThresholdsKey = 'sent_duty_threshold_notifications';

  Timer? _notificationTimer;
  bool _timeZoneInitialized = false;
  final List<int> _dutyHourThresholds = [8, 10, 12]; // Duty-hour based thresholds
  final Set<String> _sentNotifications = {}; // Track sent notifications to avoid duplicates
  final Set<String> _processedAlerts = {}; // Track processed alerts to avoid duplicates
  final Set<String> _scheduledDutiesInSession = {}; // Track duties already scheduled during this app run

  Future<void> initialize() async {

    _initializeTimeZone();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('notification_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permissions
    await _requestPermissions();

    // Restore sent threshold markers so alerts are not repeated after app restarts.
    await _loadSentNotificationState();
    
    // Start monitoring for notifications
    _startNotificationMonitoring();

    // Setup Firebase Messaging
    await _setupFirebaseMessaging();

    // Re-schedule alerts for active duties after app restart.
    await _rescheduleActiveDutyNotifications();
    
  }

  Future<void> _loadSentNotificationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedKeys = prefs.getStringList(_sentDutyThresholdsKey) ?? [];
      _sentNotifications
        ..clear()
        ..addAll(storedKeys);
    } catch (e) {
      print('⚠️ Failed to load sent notification state: $e');
    }
  }

  Future<void> _saveSentNotificationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_sentDutyThresholdsKey, _sentNotifications.toList());
    } catch (e) {
      print('⚠️ Failed to persist sent notification state: $e');
    }
  }

  void _initializeTimeZone() {
    if (_timeZoneInitialized) {
      return;
    }
    tz_data.initializeTimeZones();
    _timeZoneInitialized = true;
  }

  Future<void> _rescheduleActiveDutyNotifications() async {
    try {
      final dbService = DatabaseService();
      final duties = await dbService.getDutyAssignments();
      // Dedupe by backend shift ID when present, otherwise by local duty ID.
      final uniqueById = <String, DutyAssignment>{};
      for (final duty in duties.where((d) => d.status == ShiftStatus.IN_PROGRESS)) {
        uniqueById[_dutyKey(duty)] = duty;
      }
      final activeDuties = uniqueById.values.toList();

      for (final duty in activeDuties) {
        await scheduleAllNotifications(duty);
      }
    } catch (e) {
      print('⚠️ Could not reschedule active duty notifications: $e');
    }
  }

  Future<void> sendTestNotification() async {
    print('🚀 Testing backend notification endpoint...');
    
    // 1. Verify local notifications are working directly
    await _showNotification(
      id: 9999,
      title: '📱 Local Test',
      body: 'If you see this, local notifications are working!',
      priority: NotificationPriority.high,
    );

    try {
      final token = await FirebaseMessaging.instance.getToken();
      print('Sending test request with current token: $token');
      
      final url = Uri.parse('https://api.dutyhours.in/api/v1/fcm/test');
      final response = await http.post(
        url,
        headers: {
          ..._authService.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode({'token': token}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Test notification request successful: ${response.body}');
      } else {
        print('❌ Test notification request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('⚠️ Error sending test notification: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );


      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('🔔 Got a message whilst in the foreground!');

        if (message.notification != null) {
          
          // Show local notification for basic notification payloads
          // We pass the data payload as a JSON string so _onNotificationTapped can parse it
          _showNotification(
            id: DateTime.now().millisecondsSinceEpoch.hashCode,
            title: message.notification!.title ?? 'New Notification',
            body: message.notification!.body ?? '',
            payload: json.encode(message.data),
            priority: NotificationPriority.high,
          );
        }

        // Parse FCM data into our Alert model if it matches expected format
        try {
          if (message.data.isNotEmpty) {
            // Adapt this depending on what your backend sends in message.data
            final alert = Alert.fromJson(message.data);
            _processAlert(alert);
          }
        } catch (e) {
          print('Error parsing FCM message to Alert: $e');
        }
      });
      
      // Handle when app is in background and user taps notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🔔 Notification tapped from background!');
        _handleFCMNavigation(message.data);
      });

      // Handle when app is completely closed and user taps notification
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('🔔 Notification tapped from terminated state!');
        // We might need a small delay here for the navigator to be ready on cold boot
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleFCMNavigation(initialMessage.data);
        });
      }

      // Also fetch and print the token automatically on every app startup!
      await getFCMToken();

    } catch (e) {
      print('⚠️ Failed to setup Firebase Messaging: $e');
    }
  }

  void _handleFCMNavigation(Map<String, dynamic> data) {
    try {
      if (data.isEmpty) return;
      
      final shiftId = data['shiftId']?.toString();
      // 'id' is standard, but some backend implementations send 'notificationId'
      final alertId = data['id']?.toString() ?? data['notificationId']?.toString();
      
      if (shiftId != null) {
        _navigateToAlertDetail(shiftId, alertId ?? '');
      }
    } catch (e) {
      print('❌ Error handling FCM navigation: $e');
    }
  }

  Future<String?> getFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token;
    } catch (e) {
      print('⚠️ Failed to get FCM token: $e');
      return null;
    }
  }

  void _startNotificationMonitoring() {
    // Check every minute for notification opportunities
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndSendNotifications();
    });
  }



  Future<void> _processAlert(Alert alert) async {
    final alertKey = alert.id;
    
    // Avoid processing the same alert multiple times
    if (_processedAlerts.contains(alertKey)) {
      return;
    }

    print('🚨 Processing new alert: ${alert.typeDisplayName} for shift ${alert.shiftId}');

    // Only notify for actionable statuses
    if (!alert.isPending) {
      _processedAlerts.add(alertKey);
      return;
    }

    String title;
    String body;
    NotificationPriority priority = NotificationPriority.high;

    final trainSuffix = (alert.shift?.trainNumber != null && alert.shift!.trainNumber.isNotEmpty) 
        ? ' - Train ${alert.shift!.trainNumber}' 
        : '';

    switch (alert.type) {
      case AlertType.DUTY_8HR:
        title = '⚠️ 8 Hour Duty Alert$trainSuffix';
        body = alert.message;
        break;
      case AlertType.DUTY_10HR:
        title = '🔴 10 Hour Duty Alert$trainSuffix';
        body = alert.message;
        priority = NotificationPriority.critical;
        break;
      case AlertType.DUTY_12HR:
        title = '🆘 12 Hour Duty Alert$trainSuffix';
        body = alert.message;
        priority = NotificationPriority.critical;
        break;
      case AlertType.RELIEF_PLANNED:
        title = '🔄 Relief Planned$trainSuffix';
        body = alert.message;
        break;
      case AlertType.SHIFT_COMPLETED:
        title = '✅ Shift Completed$trainSuffix';
        body = alert.message;
        priority = NotificationPriority.defaultPriority;
        break;
      default:
        title = alert.title.isNotEmpty ? '${alert.title}$trainSuffix' : '📢 Duty Alert$trainSuffix';
        body = alert.message;
    }

    await _showNotification(
      id: alert.id.hashCode,
      title: title,
      body: body,
      payload: 'alert_${alert.shiftId}_${alert.id}',
      priority: priority,
    );

    _processedAlerts.add(alertKey);
    print('✅ Alert notification sent: ${alert.typeDisplayName}');
  }

  Future<void> _checkAndSendNotifications() async {
    try {
      // Check active duties and trigger elapsed duty-hour notifications.
      final dbService = DatabaseService();
      final duties = await dbService.getDutyAssignments();
      final activeDuties = duties.where((duty) => 
        duty.status == ShiftStatus.IN_PROGRESS &&
        !duty.startTime.isAfter(DateTime.now())
      ).toList();

      for (final duty in activeDuties) {
        await _sendDutyNotification(duty);
      }
    } catch (e) {
      print('Error checking notifications: $e');
    }
  }

  Future<void> _sendDutyNotification(DutyAssignment duty) async {
    final hoursWorked = duty.duration.inHours;
    final minutesWorked = duty.duration.inMinutes % 60;

    // Find thresholds already reached for this duty.
    final reachedThresholds = _dutyHourThresholds.where((h) => hoursWorked >= h).toList();
    if (reachedThresholds.isEmpty) {
      return;
    }

    // Send only the highest newly reached threshold to avoid backlog spam.
    final int thresholdToNotify = reachedThresholds.last;
    final String targetKey = '${duty.id}_hr_$thresholdToNotify';
    if (_sentNotifications.contains(targetKey)) {
      return;
    }

    // Mark lower reached thresholds as processed so we don't send old alerts later.
    for (final reached in reachedThresholds) {
      _sentNotifications.add('${duty.id}_hr_$reached');
    }
    await _saveSentNotificationState();

    String title;
    String body;
    NotificationPriority priority = NotificationPriority.defaultPriority;

    switch (thresholdToNotify) {
      case 12:
        title = '🚫 12 Hour Alert - Train ${duty.trainNumber}';
        body = 'Maximum duty limit reached (${hoursWorked}h ${minutesWorked}m). Immediate action required.';
        priority = NotificationPriority.critical;
        break;
      case 10:
        title = '🔴 10 Hour Alert - Train ${duty.trainNumber}';
        body = 'Critical overtime reached (${hoursWorked}h ${minutesWorked}m).';
        priority = NotificationPriority.critical;
        break;
      case 8:
        title = '⏰ 8 Hour Warning - Train ${duty.trainNumber}';
        body = 'Approaching duty limit. Current duty: ${hoursWorked}h ${minutesWorked}m.';
        priority = NotificationPriority.high;
        break;
      default:
        title = '🚂 Duty Update - Train ${duty.trainNumber}';
        body = 'Duty in progress: ${hoursWorked}h ${minutesWorked}m.';
    }

    await _showNotification(
      id: duty.id.hashCode + thresholdToNotify, // Unique ID for each duty-threshold combination
      title: title,
      body: body,
      payload: duty.id,
      priority: priority,
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.defaultPriority,
  }) async {
    print('🔔 Showing notification: $title');
    
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      priority == NotificationPriority.critical ? 'critical_alerts_v2' : 'duty_notifications_v2',
      priority == NotificationPriority.critical ? 'Critical Alerts' : 'Duty Notifications',
      channelDescription: priority == NotificationPriority.critical 
          ? 'Critical duty hour alerts requiring immediate attention'
          : 'Notifications for train duty updates and reminders',
      importance: priority == NotificationPriority.critical 
          ? Importance.max
          : priority == NotificationPriority.high 
              ? Importance.high 
              : Importance.defaultImportance,
      priority: priority == NotificationPriority.critical 
          ? Priority.max
          : priority == NotificationPriority.high 
              ? Priority.high 
              : Priority.defaultPriority,
      showWhen: true,
      icon: 'notification_icon',
      color: priority == NotificationPriority.critical 
          ? const Color(0xFFD32F2F) // Red for critical
          : priority == NotificationPriority.high
              ? const Color(0xFFFF9800) // Orange for high
              : const Color(0xFFFF6B35), // Default orange
      playSound: true,
      enableVibration: true,
      fullScreenIntent: priority == NotificationPriority.critical,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    
    print('✅ Notification displayed successfully');
  }

  AndroidNotificationDetails _buildAndroidDetails(NotificationPriority priority) {
    return AndroidNotificationDetails(
      priority == NotificationPriority.critical ? 'critical_alerts' : 'duty_notifications',
      priority == NotificationPriority.critical ? 'Critical Alerts' : 'Duty Notifications',
      channelDescription: priority == NotificationPriority.critical
          ? 'Critical duty hour alerts requiring immediate attention'
          : 'Notifications for train duty updates and reminders',
      importance: priority == NotificationPriority.critical
          ? Importance.max
          : priority == NotificationPriority.high
              ? Importance.high
              : Importance.defaultImportance,
      priority: priority == NotificationPriority.critical
          ? Priority.max
          : priority == NotificationPriority.high
              ? Priority.high
              : Priority.defaultPriority,
      showWhen: true,
      icon: 'notification_icon',
      color: priority == NotificationPriority.critical
          ? const Color(0xFFD32F2F)
          : priority == NotificationPriority.high
              ? const Color(0xFFFF9800)
              : const Color(0xFFFF6B35),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: priority == NotificationPriority.critical,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required NotificationPriority priority,
    String? payload,
  }) async {
    final details = NotificationDetails(android: _buildAndroidDetails(priority));
    final scheduleAt = tz.TZDateTime.from(scheduledTime, tz.local);

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduleAt,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    } on PlatformException catch (e) {
      // Recovery path for plugin cache corruption seen as "Missing type parameter".
      if ((e.message ?? '').contains('Missing type parameter')) {
        print('⚠️ Scheduled notification cache corrupted. Clearing and retrying...');
        await _flutterLocalNotificationsPlugin.cancelAll();

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduleAt,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return;
      }
      rethrow;
    }
  }

  int _dutyThresholdNotificationId(String dutyId, int thresholdHour) {
    final seed = '$dutyId:$thresholdHour'.hashCode;
    return seed < 0 ? -seed : seed;
  }

  String _dutyKey(DutyAssignment duty) => duty.backendShiftId ?? duty.id;

  ({String title, String body, NotificationPriority priority}) _buildDutyThresholdMessage(
    DutyAssignment duty,
    int threshold,
  ) {
    switch (threshold) {
      case 12:
        return (
          title: '🚫 12 Hour Alert - Train ${duty.trainNumber}',
          body: 'Maximum duty limit reached. Immediate action required.',
          priority: NotificationPriority.critical,
        );
      case 10:
        return (
          title: '🔴 10 Hour Alert - Train ${duty.trainNumber}',
          body: 'Critical overtime reached.',
          priority: NotificationPriority.critical,
        );
      case 8:
        return (
          title: '⏰ 8 Hour Warning - Train ${duty.trainNumber}',
          body: 'Approaching duty limit.',
          priority: NotificationPriority.high,
        );
      default:
        return (
          title: '🚂 Duty Update - Train ${duty.trainNumber}',
          body: 'Duty in progress.',
          priority: NotificationPriority.defaultPriority,
        );
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) async {
    final payload = notificationResponse.payload;
    if (payload != null) {
      

      try {
        // Try parsing it as JSON first (from our updated FCM foreground handler)
        final Map<String, dynamic> data = json.decode(payload);
        _handleFCMNavigation(data);
        return;
      } catch (_) {
        // If it's not JSON, it must be the legacy string format
        if (payload.startsWith('alert_')) {
          // Handle alert notification tap — navigate to focused AlertDetailScreen
          final parts = payload.split('_');
          if (parts.length >= 3) {
            final shiftId = parts[1];
            final alertId = parts[2];
            await _navigateToAlertDetail(shiftId, alertId);
          }
        } else {
          // Handle duty notification tap
          await _navigateToDutyDetail(payload);
        }
      }
    }
  }

  /// Navigates to the focused [AlertDetailScreen] for a specific alert.
  /// This is used when the user taps a push notification so they land
  /// directly on the alert they acted on, rather than the full list.
  Future<void> _navigateToAlertDetail(String shiftId, String alertId) async {
    try {
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AlertDetailScreen(
              shiftId: shiftId,
              alertId: alertId,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error navigating to AlertDetailScreen: $e');
      // Fallback to duty detail
      await _navigateToDutyDetail(shiftId);
    }
  }

  Future<void> _navigateToDutyDetail(String dutyId) async {
    try {
      final dbService = DatabaseService();
      final duties = await dbService.getDutyAssignments();
      final duty = duties.where((d) => d.id == dutyId).firstOrNull;
      
      if (duty != null) {
        final crewMembers = await dbService.getCrewMembers();
        
        final context = NavigationService.navigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DutyDetailScreen(
                duty: duty,
                crewMembers: crewMembers,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error navigating to duty detail: $e');
    }
  }

  // Manual alert notification for immediate alerts
  Future<void> sendAlertNotification(Alert alert) async {
    print('🚨 Sending immediate alert notification: ${alert.typeDisplayName}');
    await _processAlert(alert);
  }

  // Send notification for alert response received
  Future<void> sendAlertResponseNotification({
    required String shiftId,
    required String alertType,
    required String response,
    String? trainNumber,
  }) async {
    final title = '✅ Alert Response Recorded';
    final body = 'Response "$response" recorded for $alertType alert${trainNumber != null ? " - Train $trainNumber" : ""}';
    
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: title,
      body: body,
      payload: 'response_$shiftId',
      priority: NotificationPriority.defaultPriority,
    );
  }

  // Send notification when shift is completed
  Future<void> sendShiftCompletionNotification({
    required String trainNumber,
    required double dutyHours,
    required String signOffStation,
  }) async {
    final title = '🏁 Shift Completed - Train $trainNumber';
    final body = 'Duty completed at $signOffStation. Total duty hours: ${dutyHours.toStringAsFixed(1)}h';
    
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: title,
      body: body,
      priority: NotificationPriority.defaultPriority,
    );
  }

  // Start monitoring notifications for a new duty
  Future<void> startDutyNotifications(DutyAssignment duty) async {
    print('Started notification monitoring for Train ${duty.trainNumber}');
    // The periodic timer will automatically handle notifications
    // Send an immediate notification to confirm setup
    await _showNotification(
      id: duty.id.hashCode,
      title: '🚂 Duty Started - Train ${duty.trainNumber}',
      body: 'Notification monitoring is now active. You will receive updates at 8, 10, and 12 duty hours.',
      payload: duty.id,
    );

    // Evaluate once immediately so long-running duties don't wait for the next timer tick.
    await _sendDutyNotification(duty);

    // Schedule OS-level notifications so they still fire in background/closed states.
    // Never fail duty creation if scheduling has a platform issue.
    try {
      await scheduleAllNotifications(duty);
    } catch (e) {
      print('⚠️ Failed to schedule duty notifications, continuing with in-app monitoring: $e');
    }
  }

  // Schedule notifications for all specified hours for a duty
  Future<void> scheduleAllNotifications(DutyAssignment duty) async {
    _initializeTimeZone();
    final dutyKey = _dutyKey(duty);

    // Prevent repeated scheduling spam for the same duty during one app run.
    if (_scheduledDutiesInSession.contains(dutyKey)) {
      return;
    }
    _scheduledDutiesInSession.add(dutyKey);

    final now = DateTime.now();

    for (final threshold in _dutyHourThresholds) {
      final scheduledTime = duty.startTime.add(Duration(hours: threshold));

      // Do not schedule past thresholds.
      if (!scheduledTime.isAfter(now)) {
        continue;
      }

      final message = _buildDutyThresholdMessage(duty, threshold);
      final id = _dutyThresholdNotificationId(dutyKey, threshold);
      await _safeZonedSchedule(
        id: id,
        title: message.title,
        body: message.body,
        scheduledTime: scheduledTime,
        priority: message.priority,
        payload: duty.id,
      );

      print('🗓️ Scheduled duty notification for ${duty.trainNumber} at $scheduledTime (threshold: ${threshold}h)');
    }
  }

  // Schedule a specific notification for a duty at a specific time
  Future<void> scheduleNotification({
    required DutyAssignment duty,
    required DateTime scheduledTime,
    String? customMessage,
  }) async {
    final duration = scheduledTime.difference(duty.startTime);
    final hoursWorked = duration.inHours;
    final minutesWorked = duration.inMinutes % 60;

    final title = '🚂 Scheduled Reminder - Train ${duty.trainNumber}';
    final body = customMessage ?? 
        'Duty time will be: ${hoursWorked}h ${minutesWorked}m at ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}';

    _initializeTimeZone();
    await _safeZonedSchedule(
      id: duty.id.hashCode + scheduledTime.millisecondsSinceEpoch.hashCode,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      priority: NotificationPriority.defaultPriority,
      payload: duty.id,
    );
  }

  // Cancel all notifications for a specific duty
  Future<void> cancelDutyNotifications(String dutyId) async {
    // Remove from sent notifications tracking
    _sentNotifications.removeWhere((key) => key.startsWith(dutyId));
    await _saveSentNotificationState();
    _scheduledDutiesInSession.remove(dutyId);

    // Cancel any scheduled threshold notifications for this duty.
    for (final threshold in _dutyHourThresholds) {
      await _flutterLocalNotificationsPlugin.cancel(_dutyThresholdNotificationId(dutyId, threshold));
    }
  }

  // Stop the notification monitoring
  void dispose() {
    print('🔔 Disposing Notification Service...');
    _notificationTimer?.cancel();
    _sentNotifications.clear();
    _processedAlerts.clear();
    _scheduledDutiesInSession.clear();
    print('✅ Notification Service disposed');
  }

  // Get notification settings/status
  Future<bool> areNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    return await androidImplementation?.areNotificationsEnabled() ?? false;
  }
}

enum NotificationPriority {
  low,
  defaultPriority,
  high,
  critical,
}