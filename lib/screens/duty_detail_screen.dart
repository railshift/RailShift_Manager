import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/crew_member.dart';
import '../models/duty_assignment.dart';
import '../services/database_service.dart';
import '../services/shift_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../screens/alert_management_screen.dart';
import '../screens/edit_duty_dialog.dart';

import '../theme/app_theme.dart';
import '../main.dart';

class DutyDetailScreen extends StatefulWidget {
  final DutyAssignment duty;
  final List<CrewMember> crewMembers;

  const DutyDetailScreen({
    super.key,
    required this.duty,
    required this.crewMembers,
  });

  @override
  State<DutyDetailScreen> createState() => _DutyDetailScreenState();
}

class _DutyDetailScreenState extends State<DutyDetailScreen> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final ShiftService _shiftService = ShiftService();
  final NotificationService _notificationService = NotificationService();
  final PermissionService _permissionService = PermissionService();
  bool _isDarkMode = true;
  late DutyAssignment _currentDuty;
  bool _isDutyEnded = false;
  DateTime? _dutyEndTime;
  bool _isLoading = true;
  Map<String, dynamic>? _shiftData;
  
  late AnimationController _timerAnimationController;
  late Animation<double> _timerAnimation;
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _isDarkMode = RailShiftManagerApp.isDarkMode.value;
    _currentDuty = widget.duty;
    
    // Initialize duty end state based on the duty's endTime
    _isDutyEnded = _currentDuty.endTime != null;
    _dutyEndTime = _currentDuty.endTime;
    
    // Fetch detailed shift data from API
    _loadShiftData();
    
    _initializeNotifications();
    
    _timerAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _timerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _timerAnimationController, curve: Curves.easeInOut),
    );
    _timerAnimationController.forward();
    
    // Start a timer to update the UI every second (only if duty is not ended)
    if (!_isDutyEnded) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && !_isDutyEnded) {
          setState(() {
            // This will trigger a rebuild every second to update the timer
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerAnimationController.dispose();
    super.dispose();
  }

  void _initializeNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('notification_icon');
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      
      await _notificationsPlugin.initialize(initializationSettings);
    } catch (e) {
      print('Failed to initialize notifications: $e');
    }
  }

  Future<void> _loadShiftData() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      // Use backend shift ID if available
      if (_currentDuty.backendShiftId != null) {
        print('🔍 Fetching shift data with backend ID: ${_currentDuty.backendShiftId}');
        final response = await _shiftService.getShiftById(_currentDuty.backendShiftId!);

        if (!mounted) return;
        setState(() {
          _shiftData = response['data'];
          _isLoading = false;
        });

        print('✅ Loaded shift data: ${_shiftData?['trainNumber']}');

        // Apply backend status/endTime to local duty so UI reflects completion
        try {
          _applyBackendShiftData(_shiftData!);
        } catch (e) {
          print('⚠️ Failed to apply backend shift data to local duty: $e');
        }

        return;
      }
      
      // If no backend shift ID, try to find by train number
      print('🔍 No backend shift ID, searching by train number: ${_currentDuty.trainNumber}');
      final matchingShift = await _shiftService.findShiftByTrainNumber(
        _currentDuty.trainNumber,
        date: _currentDuty.startTime,
      );

      if (!mounted) return;
      if (matchingShift != null) {
        setState(() {
          _shiftData = matchingShift;
          _isLoading = false;
        });
        
        print('✅ Found matching shift: ${matchingShift['id']}');
        
        // Update local duty with the found backend shift ID
        _updateDutyWithBackendId(matchingShift['id']);
        // Also apply backend status/endTime immediately
        try {
          _applyBackendShiftData(matchingShift);
        } catch (e) {
          print('⚠️ Failed to apply backend shift data to local duty: $e');
        }
      } else {
        setState(() => _isLoading = false);
        print('ℹ️ No matching shift found on backend');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('❌ Error loading shift data: $e');
      
      // If we have a backend shift ID but it failed, try searching by train number
      if (_currentDuty.backendShiftId != null) {
        print('🔄 Backend shift ID failed, trying to find shift by train number...');
        try {
          final allShiftsResponse = await _shiftService.getAllShifts(
            trainNumber: _currentDuty.trainNumber,
            limit: 5,
          );
          
          final shifts = allShiftsResponse['data'] as List? ?? [];
          final matchingShift = shifts.where((shift) => 
            shift['trainNumber'] == _currentDuty.trainNumber &&
            shift['status'] != 'CANCELLED'
          ).firstOrNull;
          
          if (matchingShift != null) {
            if (!mounted) return;
            setState(() {
              _shiftData = matchingShift;
            });
            print('✅ Found matching shift by train number: ${matchingShift['id']}');
            return;
          }
        } catch (searchError) {
          print('❌ Failed to search for shift by train number: $searchError');
        }
      }
      
      // Don't show error snackbar, just continue with existing duty data
      // The UI will fallback to using _currentDuty data
      print('ℹ️ Continuing with existing duty data as fallback');
    }
  }

  /// Merge backend shift fields (status, signOffDateTime) into local duty and persist
  void _applyBackendShiftData(Map<String, dynamic> backendShift) {
    if (backendShift == null) return;

    // Parse potential sign-off / completion timestamp
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (e) {
        return null;
      }
    }

    final signOff = parseDate(backendShift['signOffDateTime'] ?? backendShift['signOffDate']);
    final statusStr = backendShift['status']?.toString()?.toUpperCase();

    if (statusStr == 'COMPLETED' || signOff != null) {
      final endTime = signOff ?? DateTime.now();

      final updated = _currentDuty.copyWith(
        endTime: endTime,
        status: ShiftStatus.COMPLETED,
      );

      // Persist and update state
      _dbService.updateDutyAssignment(updated).then((_) {
        if (!mounted) return;
        setState(() {
          _currentDuty = updated;
          _isDutyEnded = true;
          _dutyEndTime = endTime;
        });
        print('🔁 Local duty updated from backend: marked COMPLETED at $endTime');
      }).catchError((e) {
        print('⚠️ Failed to persist backend-completed duty locally: $e');
      });
    }
  }

  CrewMember? _getCrewMember(String id) {
    try {
      return widget.crewMembers.where((c) => c.id == id).firstOrNull;
    } catch (e) {
      return null;
    }
  }

  Duration get _currentDuration {
    if (_isDutyEnded && _dutyEndTime != null) {
      return Duration.zero; // Return 0 duration when duty is ended
    }
    final duration = DateTime.now().difference(_currentDuty.startTime);
    return duration.isNegative ? Duration.zero : duration;
  }
  
  Duration get _totalDutyDuration {
    // This returns the actual duration worked (for notifications)
    if (_isDutyEnded && _dutyEndTime != null) {
      return _dutyEndTime!.difference(_currentDuty.startTime);
    }
    final duration = DateTime.now().difference(_currentDuty.startTime);
    return duration.isNegative ? Duration.zero : duration;
  }

  bool get _isDutyNotStarted => DateTime.now().isBefore(_currentDuty.startTime);

  bool get _isOvertime {
    return _totalDutyDuration.inHours >= 9;
  }

  bool get _isApproachingLimit {
    return _totalDutyDuration.inHours >= 8 && _totalDutyDuration.inHours < 9;
  }

  bool get _shouldShowApiUnavailable {
    // Only show API unavailable card if we have a backend shift ID but no data
    // This indicates the shift exists on backend but we couldn't fetch it
    return _currentDuty.backendShiftId != null;
  }

  Future<void> _updateDutyWithBackendId(String backendShiftId) async {
    try {
      final updatedDuty = _currentDuty.copyWith(backendShiftId: backendShiftId);
      await _dbService.updateDutyAssignment(updatedDuty);

      if (!mounted) return;
      setState(() {
        _currentDuty = updatedDuty;
      });
      
      print('✅ Updated duty with backend shift ID: $backendShiftId');
    } catch (e) {
      print('❌ Failed to update duty with backend ID: $e');
    }
  }

  List<Map<String, dynamic>> _createBasicDutyLogs() {
    final logs = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final startTime = _currentDuty.startTime;
    final currentDuration = now.difference(startTime);
    
    // Sign On log
    logs.add({
      'id': 'local_sign_on',
      'logType': 'SIGN_ON',
      'logTime': startTime.toIso8601String(),
      'dutyHoursAtLog': 0.0,
      'remarks': 'Duty started - Sign on recorded',
    });
    
    // Departure log (if departure time is available)
    if (_currentDuty.departureTime != null) {
      final departureHours = _currentDuty.departureTime!.difference(startTime).inMinutes / 60.0;
      logs.add({
        'id': 'local_departure',
        'logType': 'DEPARTURE',
        'logTime': _currentDuty.departureTime!.toIso8601String(),
        'dutyHoursAtLog': departureHours,
        'remarks': 'Train departed from ${_currentDuty.fromStation ?? 'station'}',
      });
    }
    
    // Current status log (if duty is ongoing)
    if (!_isDutyEnded) {
      logs.add({
        'id': 'local_current',
        'logType': 'IN_PROGRESS',
        'logTime': now.toIso8601String(),
        'dutyHoursAtLog': currentDuration.inMinutes / 60.0,
        'remarks': 'Duty in progress - ${currentDuration.inHours}h ${currentDuration.inMinutes % 60}m elapsed',
      });
    }
    
    // End duty log (if duty is completed)
    if (_isDutyEnded && _dutyEndTime != null) {
      final totalHours = _dutyEndTime!.difference(startTime).inMinutes / 60.0;
      logs.add({
        'id': 'local_end',
        'logType': 'RELEASE',
        'logTime': _dutyEndTime!.toIso8601String(),
        'dutyHoursAtLog': totalHours,
        'remarks': 'Duty completed - Total duration: ${totalHours.toStringAsFixed(1)}h',
      });
    }
    
    return logs;
  }

  @override
  Widget build(BuildContext context) {

    // Use API data if available, fallback to local crew data
    final apiLocoPilot = _shiftData?['locoPilot'];
    final apiTrainManager = _shiftData?['trainManager'];
    
    final guard = _getCrewMember(_currentDuty.guardId ?? '');
    final pilot = _getCrewMember(_currentDuty.locoPilotId ?? '');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        title: Text('Train ${_currentDuty.trainNumber}'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlertManagementScreen(
                    shiftId: _currentDuty.backendShiftId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.notifications_active),
            tooltip: 'View Alerts',
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bookmark feature coming soon')),
              );
            },
            icon: const Icon(Icons.bookmark_border),
          ),
          if (!_permissionService.isRegularUser())
            IconButton(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => EditDutyDialog(
                    duty: _currentDuty,
                    backendShiftData: _shiftData,
                    onDutyUpdated: () {},
                  ),
                );
                
                if (result == true) {
                  _loadShiftData();
                }
              },
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Shift',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDutyTimerCard(),
            const SizedBox(height: 20),
            // Action buttons right below the duty timer
            _buildActionButtons(),
            // Show view-only notice for regular users
            if (_permissionService.isRegularUser()) ...[
              const SizedBox(height: 12),
              _buildViewOnlyNotice(),
            ],
            const SizedBox(height: 20),
            _buildTrainInfoCard(),
            const SizedBox(height: 20),
            _buildCrewInfoCard(guard, pilot, apiTrainManager, apiLocoPilot),
            const SizedBox(height: 20),
            _buildDutyProgressCard(),
            const SizedBox(height: 20),
            // Always show duty logs section
            _buildDutyLogsCard(),
            const SizedBox(height: 20),
            // Show API unavailable notice if needed
            if (!_isLoading && _shiftData == null && _shouldShowApiUnavailable) ...[
              _buildApiUnavailableCard(),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyTimerCard() {
    final duration = _currentDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT DUTY',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDutyEnded 
                          ? 'DUTY ENDED'
                          : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: _isDutyEnded
                            ? AppTheme.successGreen
                            : _isOvertime 
                                ? AppTheme.errorRed 
                                : _isApproachingLimit 
                                    ? AppTheme.warningOrange 
                                    : AppTheme.accentOrange,
                        fontWeight: FontWeight.w800,
                        fontSize: _isDutyEnded ? 28 : 36,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: AppTheme.successGreen,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isDutyEnded
                    ? AppTheme.successGreen.withOpacity(0.1)
                    : _isOvertime 
                        ? AppTheme.errorRed.withOpacity(0.1)
                        : _isApproachingLimit 
                            ? AppTheme.warningOrange.withOpacity(0.1)
                            : AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDutyEnded
                      ? AppTheme.successGreen.withOpacity(0.3)
                      : _isOvertime 
                          ? AppTheme.errorRed.withOpacity(0.3)
                          : _isApproachingLimit 
                              ? AppTheme.warningOrange.withOpacity(0.3)
                              : AppTheme.successGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDutyEnded
                        ? Icons.check_circle_rounded
                        : _isOvertime 
                            ? Icons.warning_rounded
                            : _isApproachingLimit 
                                ? Icons.schedule_rounded
                                : Icons.check_circle_rounded,
                    color: _isDutyEnded
                        ? AppTheme.successGreen
                        : _isOvertime 
                            ? AppTheme.errorRed
                            : _isApproachingLimit 
                                ? AppTheme.warningOrange
                                : AppTheme.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDutyEnded
                        ? 'DUTY COMPLETED SUCCESSFULLY'
                        : _isOvertime 
                            ? '!! EXCEEDED 9 HOURS !!'
                            : _isApproachingLimit 
                                ? 'APPROACHING 9-HOUR LIMIT'
                                : 'ON DUTY - WITHIN LIMITS',
                    style: TextStyle(
                      color: _isDutyEnded
                          ? AppTheme.successGreen
                          : _isOvertime 
                              ? AppTheme.errorRed
                              : _isApproachingLimit 
                                  ? AppTheme.warningOrange
                                  : AppTheme.successGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.train_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Train Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Train Number', _shiftData?['trainNumber'] ?? _currentDuty.trainNumber, Icons.confirmation_number),
            if ((_shiftData?['trainName'] != null) || (_currentDuty.trainName != null && _currentDuty.trainName!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Train Name', _shiftData?['trainName'] ?? _currentDuty.trainName!, Icons.train_outlined),
            ],
            if (_shiftData?['locomotive'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Locomotive', _shiftData!['locomotive']['locomotiveNo'] ?? 'N/A', Icons.directions_railway),
              const SizedBox(height: 12),
              _buildInfoRow('Loco Status', _shiftData!['locomotive']['status'] ?? 'UNKNOWN', Icons.settings),
            ] else if (_currentDuty.locomotiveNo != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Locomotive', _currentDuty.locomotiveNo!, Icons.directions_railway),
            ],
            const SizedBox(height: 12),
            _buildInfoRow('Route', '${_shiftData?['signOnStation'] ?? _currentDuty.fromStation} → ${_shiftData?['signOffStation'] ?? _currentDuty.toStation}', Icons.route),
            if (_shiftData?['section'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Section', _shiftData!['section'], Icons.map),
            ] else if (_currentDuty.section != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Section', _currentDuty.section!, Icons.map),
            ],
            if (_shiftData?['dutyType'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Duty Type', _shiftData!['dutyType'], Icons.work),
            ] else if (_currentDuty.dutyType != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Duty Type', _currentDuty.dutyType!, Icons.work),
            ],
            const SizedBox(height: 12),
            _buildInfoRow('Started At', _formatTime(_currentDuty.startTime), Icons.schedule),
            if (_shiftData?['dutyHours'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Total Duty Hours', '${_shiftData!['dutyHours'].toStringAsFixed(1)}h', Icons.timer),
            ],
            const SizedBox(height: 12),
            _buildInfoRow('Status', _currentDuty.status.displayName, Icons.info_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildCrewInfoCard(CrewMember? guard, CrewMember? pilot, Map<String, dynamic>? apiTrainManager, Map<String, dynamic>? apiLocoPilot) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Crew Members',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildApiCrewMemberCard(
                    apiTrainManager, 
                    guard, 
                    'Train Manager', 
                    Icons.security_rounded, 
                    Colors.blue
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildApiCrewMemberCard(
                    apiLocoPilot, 
                    pilot, 
                    'Loco Pilot', 
                    Icons.train_rounded, 
                    Colors.green
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiCrewMemberCard(Map<String, dynamic>? apiData, CrewMember? fallbackMember, String role, IconData icon, Color color) {
    // Use API data if available, otherwise fallback to local data
    final name = apiData?['name'] ?? fallbackMember?.name ?? 'Not Assigned';
    final employeeId = apiData?['employeeId'] ?? fallbackMember?.employeeId ?? 'N/A';
    final phone = apiData?['phone'] ?? 'N/A';
    final status = apiData?['status'] ?? (fallbackMember != null ? 'ASSIGNED' : 'UNKNOWN');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            role,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            employeeId,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          if (phone != 'N/A') ...[
            const SizedBox(height: 4),
            Text(
              phone,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: status == 'ON_DUTY' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.replaceAll('_', ' '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: status == 'ON_DUTY' ? Colors.green : Colors.orange,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewMemberCard(CrewMember? member, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            member?.role.displayName ?? 'Unknown Role',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            member?.name ?? 'Not Assigned',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            member?.employeeId ?? 'N/A',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDutyProgressCard() {
    final duration = _totalDutyDuration;
    final progress = (duration.inMinutes / (9 * 60)).clamp(0.0, 1.0);
    
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Duty Progress',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _isOvertime ? AppTheme.errorRed : AppTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0:00', style: Theme.of(context).textTheme.bodySmall),
                    Text('8:30', style: Theme.of(context).textTheme.bodySmall),
                    Text('9:00', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _timerAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: progress * _timerAnimation.value,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isOvertime 
                            ? AppTheme.errorRed 
                            : _isApproachingLimit 
                                ? AppTheme.warningOrange 
                                : AppTheme.accentOrange,
                      ),
                      minHeight: 8,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Start',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      'Approaching Limit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.warningOrange,
                      ),
                    ),
                    Text(
                      '9-Hour Limit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.errorRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyLogsCard() {
    // Get duty logs from API data if available, otherwise create basic logs from local data
    final apiDutyLogs = _shiftData?['dutyLogs'] as List? ?? [];
    
    // Create basic duty logs from local duty data if no API logs available
    final basicDutyLogs = apiDutyLogs.isEmpty ? _createBasicDutyLogs() : apiDutyLogs;
    
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Duty Logs',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (basicDutyLogs.isEmpty)
              Center(
                child: Text(
                  'No duty logs available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              )
            else
              ...basicDutyLogs.map((log) => _buildDutyLogItem(log)),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyLogItem(Map<String, dynamic> log) {
    final logType = log['logType']?.toString() ?? 'UNKNOWN';
    final logTime = log['logTime'] != null 
        ? DateTime.tryParse(log['logTime'].toString()) 
        : null;
    final dutyHours = log['dutyHoursAtLog']?.toString() ?? '0';
    final remarks = log['remarks']?.toString() ?? '';
    
    IconData icon;
    Color color;
    
    switch (logType) {
      case 'SIGN_ON':
        icon = Icons.login;
        color = Colors.green;
        break;
      case 'DEPARTURE':
        icon = Icons.departure_board;
        color = Colors.blue;
        break;
      case 'IN_PROGRESS':
        icon = Icons.play_circle;
        color = Colors.orange;
        break;
      case 'ARRIVAL':
        icon = Icons.flight_land;
        color = Colors.orange;
        break;
      case 'RELEASE':
      case 'SIGN_OFF':
        icon = Icons.logout;
        color = Colors.red;
        break;
      case 'BREAK':
        icon = Icons.coffee;
        color = Colors.brown;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      logType.replaceAll('_', ' '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      '${dutyHours}h',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (logTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(logTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    remarks,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiUnavailableCard() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Additional Details Unavailable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Detailed shift information from the server is currently unavailable. Basic duty information is shown above.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadShiftData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isDutyEnded) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen),
            const SizedBox(width: 8),
            Text(
              'DUTY COMPLETED SUCCESSFULLY',
              style: TextStyle(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_isDutyNotStarted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'DUTY NOT STARTED YET',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final dutyHours = _totalDutyDuration.inHours;
    final dutyMinutes = _totalDutyDuration.inMinutes;
    
    // Dynamic button logic based on duty hours
    if (dutyHours < 8) {
      // Less than 8 hours - No action buttons, just info
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, color: AppTheme.successGreen),
            const SizedBox(width: 8),
            Text(
              'DUTY ONGOING - WITHIN NORMAL HOURS',
              style: TextStyle(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    } else if (dutyHours >= 8 && dutyHours < 10) {
      // 8-10 hours - Two options: Plan Relief or End Duty
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _permissionService.canPerformDutyActions() ? () => _planRelief() : null,
              icon: const Icon(Icons.schedule, color: Colors.white),
              label: const Text(
                'PLAN RELIEF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionService.canPerformDutyActions() 
                    ? AppTheme.warningOrange 
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _permissionService.canPerformDutyActions() ? () => _showEndDutyDialog() : null,
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text(
                'END DUTY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionService.canPerformDutyActions() 
                    ? AppTheme.errorRed 
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (dutyHours >= 10 && dutyHours < 12) {
      // 10-12 hours - Two options: Keep On Duty or End Duty
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _permissionService.canPerformDutyActions() ? () => _keepOnDuty() : null,
              icon: const Icon(Icons.trending_up, color: Colors.white),
              label: const Text(
                'KEEP ON DUTY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionService.canPerformDutyActions() 
                    ? Colors.red.shade700 
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _permissionService.canPerformDutyActions() ? () => _showEndDutyDialog() : null,
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text(
                'END DUTY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionService.canPerformDutyActions() 
                    ? AppTheme.errorRed 
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // 12+ hours - Two options: Emergency Relief or End Duty
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _permissionService.canPerformDutyActions() ? () => _emergencyRelief() : null,
              icon: const Icon(Icons.warning, color: Colors.white),
              label: const Text(
                'EMERGENCY RELIEF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionService.canPerformDutyActions() 
                    ? Colors.red.shade900 
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _permissionService.canPerformDutyActions() ? () => _showEndDutyDialog() : null,
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text(
                'END DUTY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionService.canPerformDutyActions() 
                    ? AppTheme.errorRed 
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildViewOnlyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View-Only Access',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You can view duty details but cannot perform actions. Contact an administrator for duty management.',
                  style: TextStyle(
                    color: Colors.blue.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
        ),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _currentAlertTypeCode() {
    final hours = _totalDutyDuration.inHours;

    if (hours >= 12) return '12HR';
    if (hours >= 10) return '10HR';
    return '8HR';
  }

  // New action methods for dynamic duty hour management
  void _planRelief() {
    print('🟡 Plan Relief tapped for ${_currentDuty.trainNumber} | duration: ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.warningOrange),
              const SizedBox(width: 8),
              const Text('Plan Relief'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duty has reached 8+ hours. Relief planning is required.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Duration: ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m'),
                    Text('Train: ${_currentDuty.trainNumber}'),
                    Text('Status: Relief planning initiated'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateDutyStatus(
                  ShiftStatus.RELIEF_PLANNED,
                  'Relief planned at ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m',
                  backendUpdates: {
                    'status': ShiftStatus.RELIEF_PLANNED.toString().split('.').last,
                    'reliefRequired': true,
                    'reliefPlanned': true,
                    'reliefReason': 'Relief planned at ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m',
                  },
                  alertResponse: 'PLAN_RELIEF',
                  successMessage: 'Relief planned successfully',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Plan Relief', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }




  Future<void> _updateDutyStatus(
    ShiftStatus newStatus,
    String note, {
    Map<String, dynamic>? backendUpdates,
    String? alertResponse,
    String? successMessage,
  }) async {
    try {
      print('📣 Updating duty status for ${_currentDuty.trainNumber}');
      print('  - Local status: ${newStatus.toString().split('.').last}');
      print('  - Note: $note');
      print('  - Backend shift ID: ${_currentDuty.backendShiftId}');
      print('  - Alert response: $alertResponse');
      print('  - Backend updates: ${backendUpdates == null ? 'none' : backendUpdates.toString()}');

      final updatedDuty = _currentDuty.copyWith(
        status: newStatus,
        notes: note,
      );

      final backendShiftId = _currentDuty.backendShiftId;

      if (backendShiftId != null) {
        if (alertResponse != null) {
          await _shiftService.submitAlertResponse(
            shiftId: backendShiftId,
            alertType: _currentAlertTypeCode(),
            response: alertResponse,
            remarks: note,
          );
        }

        if (backendUpdates != null && backendUpdates.isNotEmpty) {
          await _shiftService.updateShift(backendShiftId, backendUpdates);
        }
      }

      await _dbService.updateDutyAssignment(updatedDuty);

      if (!mounted) return;
      setState(() {
        _currentDuty = updatedDuty;
      });
      
      _showSuccessMessage(successMessage ?? 'Duty status updated successfully');
    } catch (e) {
      _showErrorMessage('Failed to update duty status: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _keepOnDuty() {
    print('🔴 Keep On Duty tapped for ${_currentDuty.trainNumber} | duration: ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.trending_up, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Keep On Duty'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duty will continue beyond 10 hours. Acknowledging overtime.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade700.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Duration: ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m'),
                    Text('Train: ${_currentDuty.trainNumber}'),
                    Text('Status: Duty continuing'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateDutyStatus(
                  ShiftStatus.IN_PROGRESS,
                  'Duty continuing at ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m',
                  backendUpdates: {
                    'status': ShiftStatus.IN_PROGRESS.toString().split('.').last,
                    'reliefRequired': true,
                  },
                  alertResponse: 'KEEP_ON_DUTY',
                  successMessage: 'Acknowledged continuing duty successfully',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _emergencyRelief() {
    print('🚨 Emergency Relief tapped for ${_currentDuty.trainNumber} | duration: ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade900),
              const SizedBox(width: 8),
              const Text('Emergency Relief'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duty has reached critical limits (12+ hours). Requesting emergency relief.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Duration: ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m'),
                    Text('Train: ${_currentDuty.trainNumber}'),
                    Text('Status: Critical Emergency Relief Required'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateDutyStatus(
                  ShiftStatus.RELIEF_PLANNED,
                  'Emergency relief requested at ${_totalDutyDuration.inHours}h ${_totalDutyDuration.inMinutes % 60}m',
                  backendUpdates: {
                    'status': ShiftStatus.RELIEF_PLANNED.toString().split('.').last,
                    'reliefRequired': true,
                    'reliefPlanned': true,
                    'reliefReason': 'Emergency relief requested at 12+ hours',
                  },
                  alertResponse: 'EMERGENCY_RELIEF',
                  successMessage: 'Emergency relief requested',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showEndDutyDialog() {
    print('🏁 End Duty dialog opened for ${_currentDuty.trainNumber} | duration: ${_currentDuration.inHours}h ${_currentDuration.inMinutes % 60}m | ended: $_isDutyEnded');
    
    DateTime selectedEndTime = DateTime.now();
    TextEditingController stationController = TextEditingController(text: _currentDuty.toStation ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: AppTheme.warningOrange,
                  ),
                  const SizedBox(width: 8),
                  const Text('End Duty'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please confirm the sign-off details to end this duty.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Duty Summary:',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Train: ${_currentDuty.trainNumber}'),
                          Text('Duration: ${_currentDuration.inHours}h ${_currentDuration.inMinutes % 60}m'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: stationController,
                      decoration: InputDecoration(
                        labelText: 'Sign-off Station',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedEndTime,
                          firstDate: _currentDuty.startTime,
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedEndTime),
                          );
                          if (time != null) {
                            setState(() {
                              selectedEndTime = DateTime(
                                date.year, date.month, date.day,
                                time.hour, time.minute,
                              );
                            });
                          }
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Sign-off Time',
                          prefixIcon: const Icon(Icons.access_time),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(_formatDateTime(selectedEndTime)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isDutyEnded ? null : () {
                    if (stationController.text.trim().isEmpty) {
                      _showErrorMessage('Sign-off station is required');
                      return;
                    }
                    Navigator.of(context).pop();
                    _endDuty(customEndTime: selectedEndTime, customStation: stationController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'End Duty',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _endDuty({String? alertResponse, String? alertRemarks, DateTime? customEndTime, String? customStation}) async {
    final endTime = customEndTime ?? DateTime.now();
    final signOffStationStr = customStation ?? _currentDuty.toStation ?? 'Unknown';
    
    try {
      print('🏁 End Duty tapped for ${_currentDuty.trainNumber}');
      print('  - End time: $endTime');
      print('  - Current duration: ${_currentDuration.inHours}h ${_currentDuration.inMinutes % 60}m');
      print('  - Backend shift ID: ${_currentDuty.backendShiftId}');
      print('  - Alert response: $alertResponse');
      print('  - Alert remarks: $alertRemarks');

      final updatedDuty = _currentDuty.copyWith(
        endTime: endTime,
        status: ShiftStatus.COMPLETED,
      );
      
      // Try to complete the shift on the backend if we have a backend shift ID
      if (_currentDuty.backendShiftId != null) {
        try {
          print('🏁 Completing shift on backend: ${_currentDuty.backendShiftId}');

          // Submit alert response with one retry on failure
          if (alertResponse != null) {
            try {
              await _shiftService.submitAlertResponse(
                shiftId: _currentDuty.backendShiftId!,
                alertType: _currentAlertTypeCode(),
                response: alertResponse,
                remarks: alertRemarks,
              );
            } catch (e) {
              print('⚠️ First attempt to submit alert response failed: $e — retrying once');
              try {
                await Future.delayed(const Duration(seconds: 1));
                await _shiftService.submitAlertResponse(
                  shiftId: _currentDuty.backendShiftId!,
                  alertType: _currentAlertTypeCode(),
                  response: alertResponse,
                  remarks: alertRemarks,
                );
                print('✅ Alert response retry succeeded');
              } catch (retryErr) {
                print('❌ Alert response retry failed: $retryErr');
              }
            }
          }

          // Attempt to complete the shift on the backend
          try {
            await _shiftService.completeShift(
              _currentDuty.backendShiftId!,
              signOffStation: signOffStationStr,
              signOffDateTime: endTime,
            );
            print('✅ Backend shift completed successfully');
          } catch (completeErr) {
            print('⚠️ Completing shift endpoint failed: $completeErr');
          }

          // Immediately re-fetch backend shift and apply its fields to local duty
          try {
            final fresh = await _shiftService.getShiftById(_currentDuty.backendShiftId!);
            if (fresh['data'] != null) {
              _applyBackendShiftData(fresh['data']);
            }
          } catch (refreshErr) {
            print('⚠️ Failed to refresh backend shift after completion attempt: $refreshErr');
          }
        } catch (backendError) {
          print('⚠️ Failed during backend completion flow: $backendError');
        }
      } else {
        print('ℹ️ No backend shift ID available, completing locally only');
      }

      // Update the duty in the local database after backend sync
      await _dbService.updateDutyAssignment(updatedDuty);
      
      setState(() {
        _currentDuty = updatedDuty;
        _isDutyEnded = true;
        _dutyEndTime = endTime;
      });
      
      // Send completion notification
      final dutyHours = endTime.difference(_currentDuty.startTime).inMinutes / 60.0;
      await _notificationService.sendShiftCompletionNotification(
        trainNumber: _currentDuty.trainNumber,
        dutyHours: dutyHours,
        signOffStation: signOffStationStr,
      );

      // Stop any pending duty-hour scheduled notifications for this duty.
      await _notificationService.cancelDutyNotifications(_currentDuty.id);
      if (_currentDuty.backendShiftId != null && _currentDuty.backendShiftId != _currentDuty.id) {
        await _notificationService.cancelDutyNotifications(_currentDuty.backendShiftId!);
      }
      
      // Stop the timer when duty is ended
      _timer?.cancel();
    } catch (e) {
      // Handle error - show error message but still update local state
      print('Failed to update duty in database: $e');
      setState(() {
        _currentDuty = _currentDuty.copyWith(
          endTime: endTime,
          status: ShiftStatus.COMPLETED,
        );
        _isDutyEnded = true;
        _dutyEndTime = endTime;
      });
      await _notificationService.cancelDutyNotifications(_currentDuty.id);
      if (_currentDuty.backendShiftId != null && _currentDuty.backendShiftId != _currentDuty.id) {
        await _notificationService.cancelDutyNotifications(_currentDuty.backendShiftId!);
      }
      _timer?.cancel();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: AppTheme.successGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Duty ended successfully',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Navigate back to previous screen after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.of(context).pop(true); // Return true to indicate duty was ended
    });
  }
  
  void _takeBreak() async {
    final guard = _getCrewMember(_currentDuty.guardId ?? '');
    final pilot = _getCrewMember(_currentDuty.locoPilotId ?? '');
    final duration = _totalDutyDuration;
    
    // Show notification
    // Get current time
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    String notificationTitle;
    String notificationBody;
    
    if (_isOvertime) {
      notificationTitle = '⚠️ Duty Time Exceeded - Train ${_currentDuty.trainNumber}';
      notificationBody = 'Total duty time now: ${duration.inHours}h ${duration.inMinutes % 60}m\n'
          'OVERTIME: Please take immediate action\n'
          'Loco Pilot: ${pilot?.name ?? 'Not Assigned'} (${pilot?.employeeId ?? 'N/A'})\n'
          'Guard: ${guard?.name ?? 'Not Assigned'} (${guard?.employeeId ?? 'N/A'})';
    } else {
      notificationTitle = 'Break Time - Train ${_currentDuty.trainNumber}';
      notificationBody = 'Total duty time now: ${duration.inHours}h ${duration.inMinutes % 60}m\n'
          'Regular break - Stay safe!\n'
          'Loco Pilot: ${pilot?.name ?? 'Not Assigned'} (${pilot?.employeeId ?? 'N/A'})\n'
          'Guard: ${guard?.name ?? 'Not Assigned'} (${guard?.employeeId ?? 'N/A'})';
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'duty_break_channel',
      'Duty Break Notifications',
      channelDescription: 'Notifications for duty break with time exceeded info',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(
        notificationBody,
        htmlFormatBigText: false,
        contentTitle: notificationTitle,
        htmlFormatContentTitle: false,
        summaryText: 'Rail Shift Manager',
        htmlFormatSummaryText: false,
      ),
    );
    
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    // Try to show notification, but don't fail if it doesn't work
    try {
      await _notificationsPlugin.show(
        0,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );
    } catch (e) {
      print('Failed to show notification: $e');
      // Show a dialog instead if notification fails
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                _isOvertime ? Icons.warning_rounded : Icons.pause_rounded,
                color: _isOvertime ? AppTheme.warningOrange : AppTheme.accentOrange,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(notificationTitle)),
            ],
          ),
          content: Text(notificationBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    
    // Also show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isOvertime ? Icons.warning_rounded : Icons.pause_rounded,
              color: _isOvertime ? AppTheme.warningOrange : AppTheme.accentOrange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isOvertime 
                    ? 'Break notification sent - Duty time exceeded!'
                    : 'Break notification sent',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}