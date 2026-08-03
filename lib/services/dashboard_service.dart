import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DashboardService {
  static const String _baseUrl = 'https://api.dutyhours.in/api/v1';
  final AuthService _authService = AuthService();

  // Singleton pattern
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  /// Get comprehensive dashboard statistics
  /// GET /api/v1/dashboard/stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final url = Uri.parse('$_baseUrl/dashboard/stats');
      

      
      final response = await http.get(
        url,
        headers: _authService.getAuthHeaders(),
      );



      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get dashboard stats');
      }
    } catch (e) {
      print('❌ Error fetching dashboard stats: $e');
      rethrow;
    }
  }

  /// Get recent activities/duty logs with filtering
  /// GET /api/v1/dashboard/recent-activities
  Future<Map<String, dynamic>> getRecentActivities({
    int limit = 20,
    int offset = 0,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (type != null) queryParams['type'] = type;

      final uri = Uri.parse('$_baseUrl/dashboard/recent-activities')
          .replace(queryParameters: queryParams);
      

      
      final response = await http.get(
        uri,
        headers: _authService.getAuthHeaders(),
      );



      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get recent activities');
      }
    } catch (e) {
      print('❌ Error fetching recent activities: $e');
      rethrow;
    }
  }

  /// Get shift trends for charts over last N days
  /// GET /api/v1/dashboard/trends
  Future<Map<String, dynamic>> getShiftTrends({
    int days = 7,
  }) async {
    try {
      final queryParams = <String, String>{
        'days': days.toString(),
      };

      final uri = Uri.parse('$_baseUrl/dashboard/trends')
          .replace(queryParameters: queryParams);
      

      
      final response = await http.get(
        uri,
        headers: _authService.getAuthHeaders(),
      );



      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get shift trends');
      }
    } catch (e) {
      print('❌ Error fetching shift trends: $e');
      rethrow;
    }
  }

  /// Get summary of active and pending alerts
  /// GET /api/v1/dashboard/alerts-summary
  Future<Map<String, dynamic>> getAlertsSummary() async {
    try {
      final url = Uri.parse('$_baseUrl/dashboard/alerts-summary');
      

      
      final response = await http.get(
        url,
        headers: _authService.getAuthHeaders(),
      );



      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get alerts summary');
      }
    } catch (e) {
      print('❌ Error fetching alerts summary: $e');
      rethrow;
    }
  }

  /// Get comprehensive dashboard data in one call
  /// This combines multiple dashboard endpoints for efficiency
  Future<Map<String, dynamic>> getComprehensiveDashboardData({
    int recentActivitiesLimit = 10,
    int trendsDays = 7,
  }) async {
    try {

      
      // Make parallel requests to all dashboard endpoints
      final futures = await Future.wait([
        getDashboardStats(),
        getRecentActivities(limit: recentActivitiesLimit),
        getShiftTrends(days: trendsDays),
        getAlertsSummary(),
      ]);

      final stats = futures[0];
      final activities = futures[1];
      final trends = futures[2];
      final alerts = futures[3];



      return {
        'success': true,
        'data': {
          'stats': stats['data'],
          'recentActivities': activities['data'],
          'trends': trends['data'],
          'alerts': alerts['data'],
          'lastUpdated': DateTime.now().toIso8601String(),
        }
      };
    } catch (e) {
      print('❌ Error fetching comprehensive dashboard data: $e');
      
      // If comprehensive fetch fails, try to get at least basic stats
      try {
        print('🔄 Attempting fallback to basic stats only...');
        final stats = await getDashboardStats();
        return {
          'success': true,
          'data': {
            'stats': stats['data'],
            'recentActivities': {'activities': [], 'pagination': {'total': 0}},
            'trends': {'trends': [], 'summary': {}},
            'alerts': {'activeAlerts': {}, 'pendingResponses': 0, 'recentAlerts': []},
            'lastUpdated': DateTime.now().toIso8601String(),
            'fallbackMode': true,
          }
        };
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        rethrow;
      }
    }
  }
}

/// Activity types for filtering recent activities
class ActivityType {
  static const String signOn = 'SIGN_ON';
  static const String signOff = 'SIGN_OFF';
  static const String alert7Hr = 'ALERT_7HR';
  static const String alert8Hr = 'ALERT_8HR';
  static const String alert9Hr = 'ALERT_9HR';
  static const String alert10Hr = 'ALERT_10HR';
  static const String alert11Hr = 'ALERT_11HR';
  static const String alert14Hr = 'ALERT_14HR';
  static const String reliefPlanned = 'RELIEF_PLANNED';
  static const String reliefNotRequired = 'RELIEF_NOT_REQUIRED';
  static const String crewRelieved = 'CREW_RELIEVED';
  static const String crewNotBooked = 'CREW_NOT_BOOKED';
  static const String keepOnDuty = 'KEEP_ON_DUTY';
  static const String crewAlreadyRelieved = 'CREW_ALREADY_RELIEVED';
  static const String release = 'RELEASE';

  static List<String> get allTypes => [
    signOn, signOff, alert7Hr, alert8Hr, alert9Hr, alert10Hr, 
    alert11Hr, alert14Hr, reliefPlanned, reliefNotRequired, 
    crewRelieved, crewNotBooked, keepOnDuty, crewAlreadyRelieved, release
  ];
}

/// Dashboard data models for type safety
class DashboardStats {
  final int totalShifts;
  final int activeShifts;
  final int completedShifts;
  final int cancelledShifts;
  final double averageDutyHours;
  final int shiftsExceedingDutyLimit;
  final int pendingAlertResponses;
  final int reliefPlannedCount;
  final List<String> topTrainNumbers;
  final List<String> topStations;
  final DateTime lastUpdated;

  DashboardStats({
    required this.totalShifts,
    required this.activeShifts,
    required this.completedShifts,
    required this.cancelledShifts,
    required this.averageDutyHours,
    required this.shiftsExceedingDutyLimit,
    required this.pendingAlertResponses,
    required this.reliefPlannedCount,
    required this.topTrainNumbers,
    required this.topStations,
    required this.lastUpdated,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalShifts: json['totalShifts'] ?? 0,
      activeShifts: json['activeShifts'] ?? 0,
      completedShifts: json['completedShifts'] ?? 0,
      cancelledShifts: json['cancelledShifts'] ?? 0,
      averageDutyHours: (json['averageDutyHours'] ?? 0.0).toDouble(),
      shiftsExceedingDutyLimit: json['shiftsExceedingDutyLimit'] ?? 0,
      pendingAlertResponses: json['pendingAlertResponses'] ?? 0,
      reliefPlannedCount: json['reliefPlannedCount'] ?? 0,
      topTrainNumbers: List<String>.from(json['topTrainNumbers'] ?? []),
      topStations: List<String>.from(json['topStations'] ?? []),
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class RecentActivity {
  final String id;
  final String shiftId;
  final String trainNumber;
  final String staffName;
  final String staffType;
  final String logType;
  final DateTime logTime;
  final double dutyHoursAtLog;
  final String? remarks;

  RecentActivity({
    required this.id,
    required this.shiftId,
    required this.trainNumber,
    required this.staffName,
    required this.staffType,
    required this.logType,
    required this.logTime,
    required this.dutyHoursAtLog,
    this.remarks,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'] ?? '',
      shiftId: json['shiftId'] ?? '',
      trainNumber: json['trainNumber'] ?? '',
      staffName: json['staffName'] ?? '',
      staffType: json['staffType'] ?? '',
      logType: json['logType'] ?? '',
      logTime: DateTime.parse(json['logTime'] ?? DateTime.now().toIso8601String()),
      dutyHoursAtLog: (json['dutyHoursAtLog'] ?? 0.0).toDouble(),
      remarks: json['remarks'],
    );
  }
}