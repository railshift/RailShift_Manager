import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/duty_assignment.dart';
import '../models/alert.dart';
import '../models/staff.dart';
import 'auth_service.dart';

class ShiftService {
  static const String _baseUrl = 'https://api.dutyhours.in/api/v1';
  final AuthService _authService = AuthService();

  // Singleton pattern
  static final ShiftService _instance = ShiftService._internal();
  factory ShiftService() => _instance;
  ShiftService._internal();

  // Retry once after token refresh if backend returns 401.
  Future<http.Response> _getWithAuthRetry(Uri uri) async {
    var response = await http.get(
      uri,
      headers: _authService.getAuthHeaders(),
    );

    if (response.statusCode == 401) {
      await _authService.handleTokenExpiration();
      response = await http.get(
        uri,
        headers: _authService.getAuthHeaders(),
      );
    }

    return response;
  }

  /// Helper method to extract data from response, handling both nested and direct array formats
  List<Map<String, dynamic>> _extractShiftsData(Map<String, dynamic> responseData) {
    final data = responseData['data'];
    
    // Actual API format: data is a direct array, pagination is a sibling key
    if (data is List) {
      print('📊 Response format: Direct array (${data.length} items)');
      return data.cast<Map<String, dynamic>>();
    }
    
    // Routes-doc format: data.shifts array with data.pagination
    if (data is Map<String, dynamic> && data.containsKey('shifts')) {
      final shifts = data['shifts'] as List? ?? [];
      print('📊 Response format: Nested with shifts key (${shifts.length} items)');
      return shifts.cast<Map<String, dynamic>>();
    }
    
    // Handle nested format with 'data' key
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final nestedData = data['data'];
      if (nestedData is List) {
        print('📊 Response format: Nested with data key (${nestedData.length} items)');
        return nestedData.cast<Map<String, dynamic>>();
      }
    }
    
    // Fallback: treat data as single item if it's a map
    if (data is Map<String, dynamic>) {
      print('📊 Response format: Single item as map');
      return [data];
    }
    
    print('⚠️ Unknown response format, returning empty list');
    return [];
  }

  /// Extract pagination from response — handles both top-level and nested formats
  Map<String, dynamic>? _extractPagination(Map<String, dynamic> responseData) {
    // Actual API: pagination is a top-level sibling of data
    if (responseData['pagination'] is Map<String, dynamic>) {
      return responseData['pagination'] as Map<String, dynamic>;
    }
    // Routes-doc format: pagination nested inside data
    final data = responseData['data'];
    if (data is Map<String, dynamic> && data['pagination'] is Map<String, dynamic>) {
      return data['pagination'] as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> createShift(DutyAssignment shift) async {
    print('🚂 Creating shift via API...');
    final url = Uri.parse('$_baseUrl/shifts');
    
    final payload = shift.toBackendPayload();
    final headers = _authService.getAuthHeaders();
    
    print('📤 Shift creation request:');
    print('  - URL: $url');
    print('  - Headers: $headers');
    print('  - Payload: ${json.encode(payload)}');
    
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode(payload),
    );

    print('📥 Shift creation response:');
    print('  - Status: ${response.statusCode}');

    final responseData = json.decode(response.body);

    if (response.statusCode == 401) {
      // Token expired
      await _authService.handleTokenExpiration();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 201 && responseData['success']) {
      print('✅ Shift created successfully: ${responseData['data']['id']}');
      return responseData;
    } else {
      if (responseData['errors'] != null) {
        print('❌ Validation errors: ${responseData['errors']}');
      }
      print('❌ Shift creation failed: ${responseData['message']}');
      throw Exception(responseData['message'] ?? 'Failed to create shift');
    }
  }

  Future<Map<String, dynamic>> getAllShifts({
    String? status,
    String? trainNumber,
    String? section,
    String? dutyType,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (trainNumber != null) queryParams['trainNumber'] = trainNumber;
      if (section != null) queryParams['section'] = section;
      if (dutyType != null) queryParams['dutyType'] = dutyType;
      if (fromDate != null) queryParams['fromDate'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['toDate'] = toDate.toIso8601String();

      final uri = Uri.parse('$_baseUrl/shifts').replace(queryParameters: queryParams);
      

      
      final response = await _getWithAuthRetry(uri);



      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get shifts');
      }
    } catch (e) {
      print('❌ Error fetching shifts: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getShiftById(String id) async {
    final url = Uri.parse('$_baseUrl/shifts/$id');
    
    final response = await _getWithAuthRetry(url);

    final responseData = json.decode(response.body);

    if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200 && responseData['success']) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Failed to get shift');
    }
  }

  Future<Map<String, dynamic>> updateShift(String id, Map<String, dynamic> updates) async {
    final url = Uri.parse('$_baseUrl/shifts/$id');
    
    final response = await http.patch(
      url,
      headers: _authService.getAuthHeaders(),
      body: json.encode(updates),
    );

    final responseData = json.decode(response.body);

    if (response.statusCode == 401) {
      await _authService.handleTokenExpiration();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200 && responseData['success']) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Failed to update shift');
    }
  }

  Future<void> deleteShift(String id) async {
    final url = Uri.parse('$_baseUrl/shifts/$id');
    
    final response = await http.delete(
      url,
      headers: _authService.getAuthHeaders(),
    );

    final responseData = json.decode(response.body);

    if (response.statusCode == 401) {
      await _authService.handleTokenExpiration();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode != 200 || !responseData['success']) {
      throw Exception(responseData['message'] ?? 'Failed to delete shift');
    }
  }

  /// Get active shifts summary with enhanced statistics
  /// Endpoint: GET /shifts/active/summary
  Future<Map<String, dynamic>> getActiveShiftsSummary() async {
    print('📊 Fetching active shifts summary...');
    final url = Uri.parse('$_baseUrl/shifts/active/summary');
    
    final response = await _getWithAuthRetry(url);

    print('📊 Active shifts summary response status: ${response.statusCode}');

    final responseData = json.decode(response.body);

    if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200 && responseData['success']) {
      print('✅ Retrieved active shifts summary');
      return responseData;
    } else {
      print('❌ Failed to get active shifts summary: ${responseData['message']}');
      // Fallback to regular active shifts if summary endpoint is not available
      print('📊 Falling back to regular active shifts endpoint...');
      return await getActiveShifts();
    }
  }

  Future<Map<String, dynamic>> getActiveShifts() async {
    // Use the canonical list endpoint with status filter, which is supported
    // by the current backend deployment.
    return await getAllShifts(
      status: 'IN_PROGRESS',
      limit: 50,
      page: 1,
    );
  }

  /// Complete a shift using the dedicated complete endpoint
  /// Endpoint: POST /shifts/:id/complete
  Future<Map<String, dynamic>> completeShift(String shiftId, {
    required String signOffStation,
    required DateTime signOffDateTime,
  }) async {
    print('🏁 Completing shift via dedicated endpoint...');
    final url = Uri.parse('$_baseUrl/shifts/$shiftId/complete');
    
    final payload = <String, dynamic>{
      'signOffStation': signOffStation,
      'signOffDateTime': signOffDateTime.toUtc().toIso8601String(),
    };
    
    print('📤 Shift completion request:');
    print('  - URL: $url');
    print('  - Payload: ${json.encode(payload)}');
    
    final response = await http.post(
      url,
      headers: _authService.getAuthHeaders(),
      body: json.encode(payload),
    );

    print('📥 Shift completion response:');
    print('  - Status: ${response.statusCode}');

    final responseData = json.decode(response.body);

    if (response.statusCode == 401) {
      await _authService.handleTokenExpiration();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200 && responseData['success']) {
      print('✅ Shift completed successfully: $shiftId');
      return responseData;
    } else {
      print('❌ Shift completion failed: ${responseData['message']}');
      throw Exception(responseData['message'] ?? 'Failed to complete shift');
    }
  }

  /// Legacy method: Complete shift using update endpoint (fallback)
  /// Use completeShift() instead for the dedicated endpoint
  Future<Map<String, dynamic>> completeShiftLegacy(String shiftId, {
    String? signOffStation,
    DateTime? signOffDateTime,
    bool? lobbySignOff,
  }) async {
    final updates = <String, dynamic>{
      'status': 'COMPLETED',
    };
    
    if (signOffStation != null) updates['signOffStation'] = signOffStation;
    if (signOffDateTime != null) updates['signOffDateTime'] = signOffDateTime.toUtc().toIso8601String();
    if (lobbySignOff != null) updates['lobbySignOff'] = lobbySignOff;
    
    return await updateShift(shiftId, updates);
  }

  /// Get shift statistics — generated from shifts data since no dedicated stats endpoint exists
  Future<Map<String, dynamic>> getShiftStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await _generateStatisticsFromShifts(fromDate, toDate);
  }

  /// Get shifts by status with proper response format handling
  Future<List<Map<String, dynamic>>> getShiftsByStatus(String status, {
    int limit = 50,
    int page = 1,
  }) async {
    try {
      final response = await getAllShifts(
        status: status,
        limit: limit,
        page: page,
      );
      
      return _extractShiftsData(response);
    } catch (e) {
      print('❌ Error fetching shifts by status: $e');
      return [];
    }
  }

  /// Get current user's active shifts
  Future<List<Map<String, dynamic>>> getMyActiveShifts() async {
    try {
      final response = await getActiveShifts();
      final shifts = _extractShiftsData(response);
      
      // Filter by current user if user info is available
      // This would need user context from AuthService
      return shifts;
    } catch (e) {
      print('❌ Error fetching my active shifts: $e');
      return [];
    }
  }

  /// Bulk update multiple shifts
  Future<Map<String, dynamic>> bulkUpdateShifts(
    List<String> shiftIds,
    Map<String, dynamic> updates,
  ) async {
    print('🔄 Bulk updating ${shiftIds.length} shifts...');
    final url = Uri.parse('$_baseUrl/shifts/bulk-update');
    
    final payload = {
      'shiftIds': shiftIds,
      'updates': updates,
    };
    
    final response = await http.patch(
      url,
      headers: _authService.getAuthHeaders(),
      body: json.encode(payload),
    );

    final responseData = json.decode(response.body);

    if (response.statusCode == 401) {
      await _authService.handleTokenExpiration();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200 && responseData['success']) {
      print('✅ Bulk update completed successfully');
      return responseData;
    } else {
      print('❌ Bulk update failed: ${responseData['message']}');
      throw Exception(responseData['message'] ?? 'Failed to bulk update shifts');
    }
  }

  // Generate statistics from shifts data when stats endpoint is not available
  Future<Map<String, dynamic>> _generateStatisticsFromShifts(DateTime? fromDate, DateTime? toDate) async {
    try {
      // Get all shifts and calculate statistics manually (use smaller limit to avoid validation error)
      final shiftsResponse = await getAllShifts(
        fromDate: fromDate,
        toDate: toDate,
        limit: 50, // Use smaller limit to avoid API validation error
      );

      final shifts = _extractShiftsData(shiftsResponse);
      
      // Calculate basic statistics
      final totalShifts = shifts.length;
      final activeShifts = shifts.where((s) => s['status'] == 'IN_PROGRESS').length;
      final completedShifts = shifts.where((s) => s['status'] == 'COMPLETED').length;
      final cancelledShifts = shifts.where((s) => s['status'] == 'CANCELLED').length;
      
      // Calculate average duty hours
      final completedShiftsWithHours = shifts.where((s) => 
        s['status'] == 'COMPLETED' && s['dutyHours'] != null).toList();
      final averageDutyHours = completedShiftsWithHours.isNotEmpty
          ? completedShiftsWithHours.map((s) => (s['dutyHours'] as num).toDouble())
              .reduce((a, b) => a + b) / completedShiftsWithHours.length
          : 0.0;

      // Group by status
      final byStatus = <String, int>{};
      final byDutyType = <String, int>{};
      final bySection = <String, int>{};

      for (final shift in shifts) {
        final status = shift['status']?.toString() ?? 'UNKNOWN';
        final dutyType = shift['dutyType']?.toString() ?? 'UNKNOWN';
        final section = shift['section']?.toString() ?? 'UNKNOWN';

        byStatus[status] = (byStatus[status] ?? 0) + 1;
        byDutyType[dutyType] = (byDutyType[dutyType] ?? 0) + 1;
        bySection[section] = (bySection[section] ?? 0) + 1;
      }

      return {
        'success': true,
        'data': {
          'totalShifts': totalShifts,
          'activeShifts': activeShifts,
          'completedShifts': completedShifts,
          'cancelledShifts': cancelledShifts,
          'averageDutyHours': averageDutyHours,
          'byStatus': byStatus,
          'byDutyType': byDutyType,
          'bySection': bySection,
        }
      };
    } catch (e) {
      print('❌ Error generating statistics from shifts: $e');
      rethrow;
    }
  }



  // Sync local duties with backend shifts
  Future<List<Map<String, dynamic>>> syncShiftsFromBackend({
    int limit = 50,
    String? status,
  }) async {
    try {
      print('🔄 Syncing shifts from backend...');
      
      final response = await getAllShifts(
        limit: limit,
        status: status,
      );
      
      final shifts = _extractShiftsData(response);
      print('✅ Synced ${shifts.length} shifts from backend');
      
      return shifts;
    } catch (e) {
      print('❌ Failed to sync shifts from backend: $e');
      return [];
    }
  }

  // Find shift by train number and date (useful for matching local duties)
  Future<Map<String, dynamic>?> findShiftByTrainNumber(
    String trainNumber, {
    DateTime? date,
  }) async {
    try {
      final response = await getAllShifts(
        trainNumber: trainNumber,
        fromDate: date?.subtract(const Duration(days: 1)),
        toDate: date?.add(const Duration(days: 1)),
        limit: 5,
      );
      
      final shifts = _extractShiftsData(response);
      
      // Find the most recent matching shift
      for (final shift in shifts) {
        if (shift['trainNumber'] == trainNumber) {
          return shift;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Failed to find shift by train number: $e');
      return null;
    }
  }

  // Import backend shifts that don't exist locally
  Future<List<DutyAssignment>> importBackendShifts({
    int limit = 50,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      print('📥 Importing shifts from backend...');
      
      final response = await getAllShifts(
        limit: limit,
        status: status,
        fromDate: fromDate,
        toDate: toDate,
      );
      
      final shifts = _extractShiftsData(response);
      final importedDuties = <DutyAssignment>[];
      
      for (final shiftData in shifts) {
        try {
          // Convert backend shift to DutyAssignment
          final duty = _convertBackendShiftToDuty(shiftData);
          importedDuties.add(duty);
        } catch (e) {
          print('❌ Failed to convert shift ${shiftData['id']}: $e');
        }
      }
      
      print('✅ Imported ${importedDuties.length} shifts from backend');
      return importedDuties;
      
    } catch (e) {
      print('❌ Failed to import backend shifts: $e');
      return [];
    }
  }

  // Convert backend shift data to DutyAssignment
  DutyAssignment _convertBackendShiftToDuty(Map<String, dynamic> shiftData) {
    // Extract crew member info
    CrewMemberInfo? locoPilot;
    CrewMemberInfo? trainManager;
    
    if (shiftData['locoPilot'] != null) {
      final lpData = shiftData['locoPilot'] as Map<String, dynamic>;
      locoPilot = CrewMemberInfo(
        employeeId: lpData['employeeId']?.toString() ?? '',
        name: lpData['name']?.toString() ?? '',
        phone: lpData['phone']?.toString() ?? '',
      );
    }
    
    if (shiftData['trainManager'] != null) {
      final tmData = shiftData['trainManager'] as Map<String, dynamic>;
      trainManager = CrewMemberInfo(
        employeeId: tmData['employeeId']?.toString() ?? '',
        name: tmData['name']?.toString() ?? '',
        phone: tmData['phone']?.toString() ?? '',
      );
    }
    
    // Parse dates safely
    DateTime? parseDate(dynamic dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr.toString());
      } catch (e) {
        return null;
      }
    }
    
    // Parse status
    ShiftStatus parseStatus(String? status) {
      switch (status?.toUpperCase()) {
        case 'SCHEDULED':
          return ShiftStatus.SCHEDULED;
        case 'IN_PROGRESS':
          return ShiftStatus.IN_PROGRESS;
        case 'COMPLETED':
          return ShiftStatus.COMPLETED;
        case 'RELIEF_PLANNED':
          return ShiftStatus.RELIEF_PLANNED;
        case 'CANCELLED':
          return ShiftStatus.CANCELLED;
        default:
          return ShiftStatus.IN_PROGRESS;
      }
    }
    
    return DutyAssignment(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}_${shiftData['trainNumber']}', // Generate local ID
      backendShiftId: shiftData['id']?.toString(), // Store backend shift ID
      trainNumber: shiftData['trainNumber']?.toString() ?? '',
      trainName: shiftData['trainName']?.toString(),
      locomotiveNo: shiftData['locomotive']?['locomotiveNo']?.toString() ?? 
                   shiftData['locomotiveNo']?.toString(),
      signOnStation: shiftData['signOnStation']?.toString(),
      signOffStation: shiftData['signOffStation']?.toString(),
      section: shiftData['section']?.toString(),
      dutyType: shiftData['dutyType']?.toString(),
      lobbySignOn: shiftData['lobbySignOn'] as bool?,
      lobbySignOff: shiftData['lobbySignOff'] as bool?,
      trainArrivalDate: parseDate(shiftData['trainArrivalDate']),
      trainArrivalTime: parseDate(shiftData['trainArrivalDateTime']),
      signOnTime: parseDate(shiftData['signOnDateTime']),
      timeOfTO: parseDate(shiftData['timeOfTO']),
      departureTime: parseDate(shiftData['departureDateTime']),
      signOffDate: null,
      signOffTime: parseDate(shiftData['signOffDateTime']),
      dutyHours: (shiftData['dutyHours'] ?? shiftData['currentDutyHours'] as num?)?.toDouble(),
      locoPilot: locoPilot,
      trainManager: trainManager,
      reliefRequired: shiftData['reliefRequired'] as bool? ?? false,
      reliefPlanned: shiftData['reliefPlanned'] as bool? ?? false,
      reliefTime: parseDate(shiftData['reliefTime']),
      reliefReason: shiftData['reliefReason']?.toString(),
      startTime: parseDate(shiftData['signOnDateTime']) ?? 
                parseDate(shiftData['departureDateTime']) ?? 
                DateTime.now(),
      endTime: parseDate(shiftData['signOffDateTime']),
      status: parseStatus(shiftData['status']?.toString()),
      createdAt: parseDate(shiftData['createdAt']) ?? DateTime.now(),
      createdBy: shiftData['createdBy']?['employeeId']?.toString() ?? 'backend',
      notes: 'Imported from backend API',
      // Legacy fields for compatibility
      fromStation: shiftData['signOnStation']?.toString(),
      toStation: shiftData['signOffStation']?.toString(),
    );
  }

  // ============================================================================
  // ALERT MANAGEMENT FUNCTIONALITY
  // ============================================================================

  /// Get alert history for a specific shift.
  /// Endpoint: GET /shifts/:id/alerts
  ///
  /// Response shape per API docs:
  /// { success, data: { shiftId, trainNumber, signOnDateTime, currentDutyHours,
  ///                    status, alertHistory: [ { type, sentAt, response, requiresAction } ] } }
  ///
  /// Returns a normalised list of alert maps under data[] so callers can do
  /// `(response['data'] as List)` regardless of the source endpoint.
  Future<Map<String, dynamic>> getShiftAlerts(String shiftId) async {
    print('🚨 === GETTING SHIFT ALERTS ===');
    print('🆔 Shift ID: $shiftId');

    final url = Uri.parse('$_baseUrl/shifts/$shiftId/alerts');
    print('🌐 API URL: $url');

    try {
      final response = await http.get(
        url,
        headers: _authService.getAuthHeaders(),
      );

      print('📥 Alert history response status: ${response.statusCode}');

      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200 && responseData['success'] == true) {
        final data = responseData['data'];

        // New API shape: data is an object with an alertHistory array.
        // Normalise to a flat list so the screen can iterate uniformly.
        if (data is Map<String, dynamic>) {
          final history = data['alertHistory'] as List? ?? [];
          final shiftIdFromResp = data['shiftId']?.toString() ?? shiftId;
          // Inject shiftId into each history item so Alert.fromJson works.
          final enriched = history.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            m['shiftId'] = shiftIdFromResp;
            return m;
          }).toList();
          print('✅ Retrieved ${enriched.length} alerts for shift $shiftId');
          return {'success': true, 'data': enriched, 'meta': data};
        }

        // Fallback: data is already a List
        if (data is List) {
          print('✅ Retrieved ${data.length} alerts for shift $shiftId');
          return responseData;
        }

        return {'success': true, 'data': <dynamic>[]};
      } else {
        print('❌ Failed to get shift alerts: ${responseData['message']}');
        throw Exception(responseData['message'] ?? 'Failed to get shift alerts');
      }
    } catch (e) {
      print('💥 Error getting shift alerts: $e');
      rethrow;
    }
  }

  /// Submit response to a duty hour alert
  /// Endpoint: POST /shifts/:id/alert-response
  Future<Map<String, dynamic>> submitAlertResponse({
    required String shiftId,
    required String alertType,
    required String response,
    String? remarks,
  }) async {
    print('🚨 === SUBMITTING ALERT RESPONSE ===');
    print('🆔 Shift ID: $shiftId');
    print('📝 Alert Type: $alertType');
    print('💬 Response: $response');
    
    final url = Uri.parse('$_baseUrl/shifts/$shiftId/alert-response');
    print('🌐 API URL: $url');
    
    final requestBody = <String, dynamic>{
      'alertType': alertType,
      'response': response,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };
    
    print('📤 Alert response request body: ${json.encode(requestBody)}');
    
    try {
      final httpResponse = await http.post(
        url,
        headers: _authService.getAuthHeaders(),
        body: json.encode(requestBody),
      );

      print('📥 Alert response submission status: ${httpResponse.statusCode}');

      final responseData = json.decode(httpResponse.body);

      if (httpResponse.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (httpResponse.statusCode == 200 && responseData['success']) {
        print('✅ Alert response submitted successfully');
        return responseData;
      } else {
        print('❌ Failed to submit alert response: ${responseData['message']}');
        throw Exception(responseData['message'] ?? 'Failed to submit alert response');
      }
    } catch (e) {
      print('💥 Error submitting alert response: $e');
      rethrow;
    }
  }

  /// Get all system alert notifications for the authenticated user.
  /// Endpoint: GET /alerts  (primary — returns rich notification objects)
  ///
  /// Returns: { success, data: [ { id, shiftId, type, title, message,
  ///            status, sentAt, acknowledgedAt, responseAction, priority, shift } ] }
  Future<Map<String, dynamic>> getPendingAlerts() async {


    final url = Uri.parse('$_baseUrl/alerts');


    try {
      final response = await _getWithAuthRetry(url);



      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200 && responseData['success'] == true) {
        final data = responseData['data'];
        final alerts = data is List ? data : <dynamic>[];

        return {'success': true, 'data': alerts};
      } else {
        print('❌ Failed to get alerts: ${responseData['message']}');
        throw Exception(responseData['message'] ?? 'Failed to get alerts');
      }
    } catch (e) {
      print('💥 Error getting alerts: $e');
      rethrow;
    }
  }

  /// Acknowledge an alert (quick response)
  Future<Map<String, dynamic>> acknowledgeAlert({
    required String shiftId,
    required String alertType,
    String? remarks,
  }) async {
    return await submitAlertResponse(
      shiftId: shiftId,
      alertType: alertType,
      response: 'RELIEF_NOT_REQUIRED',
      remarks: remarks,
    );
  }

  /// Request relief for a shift due to duty hour concerns
  Future<Map<String, dynamic>> requestRelief({
    required String shiftId,
    required String alertType,
    required String reason,
  }) async {
    return await submitAlertResponse(
      shiftId: shiftId,
      alertType: alertType,
      response: 'PLAN_RELIEF',
      remarks: reason,
    );
  }

  /// Mark that relief is not required for the current alert
  Future<Map<String, dynamic>> reliefNotRequired({
    required String shiftId,
    required String alertType,
    required String reason,
  }) async {
    return await submitAlertResponse(
      shiftId: shiftId,
      alertType: alertType,
      response: 'RELIEF_NOT_REQUIRED',
      remarks: reason,
    );
  }

  /// Indicate continuing duty despite alert
  Future<Map<String, dynamic>> continueDuty({
    required String shiftId,
    required String alertType,
    required String justification,
  }) async {
    return await submitAlertResponse(
      shiftId: shiftId,
      alertType: alertType,
      response: 'KEEP_ON_DUTY',
      remarks: justification,
    );
  }

  /// Escalate an alert to higher authority
  Future<Map<String, dynamic>> escalateAlert({
    required String shiftId,
    required String alertType,
    required String escalationReason,
  }) async {
    return await submitAlertResponse(
      shiftId: shiftId,
      alertType: alertType,
      response: 'ESCALATE',
      remarks: escalationReason,
    );
  }

  /// Mark an alert as resolved
  Future<Map<String, dynamic>> resolveAlert({
    required String shiftId,
    required String alertType,
    required String resolution,
  }) async {
    return await submitAlertResponse(
      shiftId: shiftId,
      alertType: alertType,
      response: 'CREW_RELIEVED',
      remarks: resolution,
    );
  }

  /// Mark that the crew has already been relieved and the duty can be closed
  Future<Map<String, dynamic>> crewAlreadyRelieved({
    required String shiftId,
    required String alertType,
    required String reason,
  }) async {
    return await submitAlertResponse(
      shiftId: shiftId,
      alertType: alertType,
      response: 'CREW_ALREADY_RELIEVED',
      remarks: reason,
    );
  }

  /// Get alert statistics derived from the GET /alerts response.
  /// NOTE: /alerts/statistics does not exist in the API — we compute counts locally.
  Future<Map<String, dynamic>> getAlertStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    print('📊 === COMPUTING ALERT STATISTICS FROM GET /alerts ===');

    try {
      final response = await getPendingAlerts();
      final alerts = response['data'] as List? ?? [];

      int pending = 0, sent = 0, acknowledged = 0, failed = 0;
      for (final a in alerts) {
        final status = (a['status'] as String?)?.toUpperCase() ?? '';
        if (status == 'PENDING')      pending++;
        else if (status == 'SENT')    sent++;
        else if (status == 'ACKNOWLEDGED') acknowledged++;
        else if (status == 'FAILED')  failed++;
      }

      print('✅ Alert statistics computed from ${alerts.length} alerts');
      return {
        'success': true,
        'data': {
          'total': alerts.length,
          'pending': pending,
          'sent': sent,
          'acknowledged': acknowledged,
          'failed': failed,
        },
      };
    } catch (e) {
      print('💥 Error computing alert statistics: $e');
      rethrow;
    }
  }
}