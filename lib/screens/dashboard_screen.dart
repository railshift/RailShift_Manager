import 'dart:async';
import 'package:flutter/material.dart';
import '../models/crew_member.dart';
import '../models/duty_assignment.dart';
import '../models/staff.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/shift_service.dart';
import '../services/dashboard_service.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../services/update_service.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'duties_screen.dart';
import 'reports_screen.dart';
import '../utils/data_parser.dart';
import 'duty_dialog.dart';
import 'help_support_screen.dart';
import 'user_management_screen.dart';
import 'alert_management_screen.dart';
import '../widgets/duty_card.dart';
import '../widgets/search_bar.dart';



class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  final ShiftService _shiftService = ShiftService();
  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();
  Map<String, String> _sectionInfo = {};
  bool _isDarkMode = false;
  List<DutyAssignment> _activeDuties = [];
  List<CrewMember> _crewMembers = [];
  bool _isLoading = true;
  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> _dashboardData = {};

  @override
  void initState() {
    super.initState();
    _isDarkMode = RailShiftManagerApp.isDarkMode.value;
    _loadData();
    UpdateService().checkForUpdates(context);
  }

  void _unfocusSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _loadData() async {
    _unfocusSearch();
    setState(() => _isLoading = true);
    
    try {
      // Load section info first so it's available for duty conversion
      final sectionInfo = await _dbService.getSectionInfo();
      setState(() {
        _sectionInfo = sectionInfo;
      });
      
      // Fetch active shifts from API only (no local fallback)
      List<DutyAssignment> activeDuties = [];
      final activeShiftsResponse = await _shiftService.getActiveShifts();

      // Safely extract active shifts data
      List<dynamic> activeShifts = [];
      final responseData = activeShiftsResponse['data'];
      if (responseData is Map<String, dynamic> && responseData['activeShifts'] is List) {
        activeShifts = responseData['activeShifts'] as List;
      } else if (responseData is List) {
        activeShifts = responseData;
      }

      activeDuties = activeShifts.map((shiftData) => _convertActiveShiftToDuty(shiftData)).toList();

      // Sort by duty hours (highest first) to show most critical duties
      activeDuties.sort((a, b) {
        final aDuration = a.duration.inMinutes;
        final bDuration = b.duration.inMinutes;
        return bDuration.compareTo(aDuration); // Descending order
      });


      
      final crewMembers = await _dbService.getCrewMembers();
      
      // Fetch comprehensive dashboard data from API only
      final dashboardResponse = await _dashboardService.getComprehensiveDashboardData(
        recentActivitiesLimit: 10,
        trendsDays: 7,
      );
      final dashboardData = dashboardResponse['data'] ?? {};

      
      setState(() {
        _activeDuties = activeDuties;
        _crewMembers = crewMembers;
        _sectionInfo = sectionInfo;
        _todayStats = dashboardData['stats'] ?? {};
        _dashboardData = dashboardData; // Store full dashboard data
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        // Check if it's a session expired error
        if (e.toString().contains('Session expired')) {
          // Don't show snackbar for session expired as it's handled globally
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  DutyAssignment _convertActiveShiftToDuty(Map<String, dynamic> shiftData) {
    // Handle both direct trainManager object and trainManagerId reference
    Map<String, dynamic>? trainManager;
    try {
      final tmData = shiftData['trainManager'];
      if (tmData is Map<String, dynamic>) {
        trainManager = tmData;
      } else if (tmData is List && tmData.isNotEmpty && tmData.first is Map<String, dynamic>) {
        trainManager = tmData.first as Map<String, dynamic>;
      } else if (shiftData['trainManagerId'] != null) {
        // Create a basic trainManager object from ID
        trainManager = {
          'id': shiftData['trainManagerId'],
          'name': 'Train Manager',
          'employeeId': shiftData['trainManagerId'],
        };
      }
    } catch (e) {
      trainManager = null;
    }
    
    // Handle both direct locoPilot object and locoPilotId reference
    Map<String, dynamic>? locoPilot;
    try {
      final lpData = shiftData['locoPilot'];
      if (lpData is Map<String, dynamic>) {
        locoPilot = lpData;
      } else if (shiftData['locoPilotId'] != null) {
        // Create a basic locoPilot object from ID
        locoPilot = {
          'id': shiftData['locoPilotId'],
          'name': 'Loco Pilot',
          'employeeId': shiftData['locoPilotId'],
        };
      }
    } catch (e) {
      locoPilot = null;
    }
    
    return DutyAssignment(
      id: shiftData['id'],
      trainNumber: shiftData['trainNumber'] ?? '',
      trainName: shiftData['trainName'],
      locomotiveNo: shiftData['locomotive']?['locomotiveNo'],
      guardId: trainManager?['id'] ?? shiftData['trainManagerId'] ?? '',
      assistantId: null,
      section: shiftData['section'] ?? _sectionInfo['sectionName'] ?? 'Railway Section',
      dutyType: shiftData['dutyType'],
      // Handle new DateTime field names
      startTime: DateTime.parse(shiftData['signOnDateTime'] ?? shiftData['signOnTime'] ?? DateTime.now().toIso8601String()),
      trainArrivalTime: shiftData['trainArrivalDateTime'] != null ? DateTime.parse(shiftData['trainArrivalDateTime']) : null,
      signOnTime: shiftData['signOnDateTime'] != null ? DateTime.parse(shiftData['signOnDateTime']) : null,
      timeOfTO: shiftData['timeOfTO'] != null ? DateTime.parse(shiftData['timeOfTO']) : null,
      departureTime: shiftData['departureDateTime'] != null ? DateTime.parse(shiftData['departureDateTime']) : null,
      endTime: shiftData['signOffDateTime'] != null ? DateTime.parse(shiftData['signOffDateTime']) : null,
      fromStation: shiftData['signOnStation'] ?? 'Active',
      toStation: shiftData['signOffStation'] ?? 'In Progress',
      signOnStation: shiftData['signOnStation'],
      signOffStation: shiftData['signOffStation'],
      dutyHours: DataParser.safeDoubleValue(shiftData['dutyHours']),
      status: _parseShiftStatus(shiftData['status']),
      notes: 'Current duty hours: ${DataParser.safeDoubleValue(shiftData['dutyHours']).toStringAsFixed(1)}h',
      createdAt: DateTime.parse(shiftData['createdAt'] ?? DateTime.now().toIso8601String()),
      createdBy: 'system',
      backendShiftId: shiftData['id'], // Store the backend shift ID
      locoPilot: locoPilot != null ? CrewMemberInfo(
        employeeId: locoPilot['employeeId'] ?? locoPilot['id'] ?? '',
        name: locoPilot['name'] ?? 'Loco Pilot',
        phone: locoPilot['phone'] ?? '',
      ) : null,
      trainManager: trainManager != null ? CrewMemberInfo(
        employeeId: trainManager['employeeId'] ?? trainManager['id'] ?? '',
        name: trainManager['name'] ?? 'Train Manager',
        phone: trainManager['phone'] ?? '',
      ) : null,
    );
  }

  ShiftStatus _parseShiftStatus(String? status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.train, color: Colors.red),
            SizedBox(width: 8),
            Text('DutyHours'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlertManagementScreen(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Alert Management',
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () {
                // Unfocus search field when tapping outside
                FocusScope.of(context).unfocus();
              },
              child: RefreshIndicator(
                onRefresh: () async {
                  _unfocusSearch();
                  await _loadData();
                },
                child: SingleChildScrollView(
                  padding: AppTheme.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    QuickSearchBar(
                    activeDuties: _activeDuties,
                    crewMembers: _crewMembers,
                    isDarkMode: _isDarkMode,
                    onRefresh: _loadData,
                  ),
                      const SizedBox(height: 14),
                      _buildActiveDutiesSection(),
                      const SizedBox(height: 16),
                      _buildQuickActions(),
                      const SizedBox(height: 16),
                      _buildRecentActivitiesSection(),
                      const SizedBox(height: 24),
                      _buildStatsOverview(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }


  Widget _buildActiveDutiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Duties',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        '${_activeDuties.length} ongoing',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.accentOrange.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DutiesScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: AppTheme.accentOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_activeDuties.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode ? [
                  AppTheme.cardBackground,
                  AppTheme.cardBackground.withOpacity(0.8),
                ] : [
                  Colors.blue.shade50,
                  Colors.blue.shade100,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDarkMode ? Colors.blue.shade600.withOpacity(0.4) : Colors.blue.shade300.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 32,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active Duties',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All crew members are currently off duty',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activeDuties.length > 2 ? 2 : _activeDuties.length,
            itemBuilder: (context, index) {
              final duty = _activeDuties[index];
              return DutyCard(
                duty: duty,
                crewMembers: _crewMembers,
                isDarkMode: _isDarkMode,
                onRefresh: _loadData,
              );
            },
          ),
      ],
    );
  }



  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Color? color,
  }) {
    final cardColor = color ?? AppTheme.accentOrange;
    
    // Helper function to get light shades for any color
    Color getLightShade(Color baseColor, double opacity) {
      return Color.alphaBlend(baseColor.withOpacity(opacity), Colors.white);
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.8),
          ] : [
            getLightShade(cardColor, 0.1),
            getLightShade(cardColor, 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isDarkMode ? cardColor.withOpacity(0.3) : cardColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cardColor.withOpacity(0.7),
                        cardColor.withOpacity(0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double progress,
    String subtitle,
  ) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground.withOpacity(0.9),
            AppTheme.cardBackground.withOpacity(0.7),
          ] : [
            Colors.white,
            color.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.2) : color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: _isDarkMode ? color.withOpacity(0.4) : color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Animated circular progress
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: clampedProgress,
                    strokeWidth: 4,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.3,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyTrendChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground.withOpacity(0.8),
            AppTheme.cardBackground.withOpacity(0.6),
          ] : [
            Colors.grey.shade50,
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.indigo.shade600.withOpacity(0.3) : Colors.indigo.shade300.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.indigo.shade600,
                      Colors.indigo.shade500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Duty Trend',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Last 7 days activity',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.green,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '12%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final heights = [0.3, 0.6, 0.4, 0.8, 0.5, 0.9, 0.7];
                final colors = [
                  Colors.blue.shade300,
                  Colors.green.shade300,
                  Colors.orange.shade300,
                  Colors.purple.shade300,
                  Colors.teal.shade300,
                  Colors.red.shade300,
                  Colors.indigo.shade300,
                ];
                final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: heights[index] * 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colors[index],
                                colors[index].withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: colors[index].withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[index],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    final activities = _dashboardData['recentActivities']?['activities'] as List? ?? [];
    final sortedActivities = List<Map<String, dynamic>>.from(activities);
    sortedActivities.sort((a, b) {
      final aTime = DateTime.tryParse(
        a['timestamp']?.toString() ?? a['logTime']?.toString() ?? '',
      );
      final bTime = DateTime.tryParse(
        b['timestamp']?.toString() ?? b['logTime']?.toString() ?? '',
      );
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history,
                color: AppTheme.accentOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${sortedActivities.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (sortedActivities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timeline,
                  size: 24,
                  color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No recent activities yet',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 230,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: sortedActivities.length > 5 ? 5 : sortedActivities.length,
              itemBuilder: (context, index) {
                final activity = sortedActivities[index];
                return _buildActivityItem(activity);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final shift = activity['shift'] as Map<String, dynamic>? ?? {};
    final staff = activity['staff'] as Map<String, dynamic>? ?? {};

    // Support both legacy and current API keys.
    final logType =
      activity['logType']?.toString() ?? activity['type']?.toString() ?? '';
    final trainNumber = activity['trainNumber']?.toString() ??
      shift['trainNumber']?.toString() ??
      'Unknown Train';
    final staffName =
      activity['staffName']?.toString() ?? staff['name']?.toString() ?? 'Staff';
    final logTime =
      activity['logTime']?.toString() ?? activity['timestamp']?.toString() ?? '';

    final dutyHoursValue = activity['dutyHoursAtLog'] ?? activity['dutyHours'] ?? 0.0;
    final dutyHours = dutyHoursValue is num
      ? dutyHoursValue.toDouble()
      : double.tryParse(dutyHoursValue.toString()) ?? 0.0;
    
    // Parse log time
    DateTime? activityTime;
    try {
      activityTime = DateTime.parse(logTime);
    } catch (e) {
      activityTime = DateTime.now();
    }
    
    // Get activity icon and color based on log type
    IconData activityIcon;
    Color activityColor;
    String activityDescription;
    
    switch (logType.toUpperCase()) {
      case 'SIGN_ON':
        activityIcon = Icons.login;
        activityColor = Colors.green;
        activityDescription = 'signed on';
        break;
      case 'SIGN_OFF':
        activityIcon = Icons.logout;
        activityColor = Colors.blue;
        activityDescription = 'signed off';
        break;
      case 'ALERT_8HR':
        activityIcon = Icons.warning;
        activityColor = Colors.orange;
        activityDescription = '8-hour alert';
        break;
      case 'ALERT_9HR':
        activityIcon = Icons.warning_amber;
        activityColor = Colors.deepOrange;
        activityDescription = '9-hour alert';
        break;
      case 'ALERT_10HR':
      case 'ALERT_11HR':
      case 'ALERT_14HR':
        activityIcon = Icons.error;
        activityColor = Colors.red;
        activityDescription = '${logType.toLowerCase().replaceAll('alert_', '').replaceAll('hr', '-hour')} alert';
        break;
      case 'RELIEF_PLANNED':
        activityIcon = Icons.schedule;
        activityColor = Colors.purple;
        activityDescription = 'relief planned';
        break;
      case 'CREW_RELIEVED':
        activityIcon = Icons.check_circle;
        activityColor = Colors.green;
        activityDescription = 'crew relieved';
        break;
      default:
        activityIcon = Icons.info;
        activityColor = Colors.grey;
        activityDescription = logType.toLowerCase().replaceAll('_', ' ');
    }
    
    // Format time ago
    final timeAgo = _formatTimeAgo(activityTime);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              activityIcon,
              color: activityColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: staffName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' $activityDescription for '),
                      TextSpan(
                        text: trainNumber,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    if (dutyHours > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${dutyHours.toStringAsFixed(1)}h duty',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: activityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              logType.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: activityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Only show Create Duty button for admins
            if (_permissionService.canCreateDuty()) ...[
              Expanded(
                child: _buildActionCard(
                  'New Duty',
                  'Assign crew to train',
                  Icons.add_circle_outline_rounded,
                  () {
                    _showCreateDutyDialog();
                  },
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: _buildActionCard(
                'View Reports',
                'Analytics & insights',
                Icons.analytics_rounded,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportsScreen(),
                    ),
                  );
                },
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsOverview() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.9),
          ] : [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _isDarkMode ? Colors.purple.shade600.withOpacity(0.4) : Colors.purple.shade300.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade600,
                        Colors.purple.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Overview',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time duty statistics',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary.withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildEnhancedStatCard(
                    'Active Shifts',
                    '${_todayStats['overview']?['activeShifts'] ?? 0}',
                    Icons.assignment_rounded,
                    AppTheme.accentOrange,
                    (_todayStats['overview']?['activeShifts'] ?? 0) / 20.0, // Progress out of 20
                    'In progress',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnhancedStatCard(
                    'Completed',
                    '${_todayStats['overview']?['completedShifts'] ?? 0}',
                    Icons.check_circle_rounded,
                    const Color(0xFF4CAF50),
                    (_todayStats['overview']?['completedShifts'] ?? 0) / 30.0, // Progress out of 30
                    'All time',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnhancedStatCard(
                    'Total Shifts',
                    '${_todayStats['overview']?['totalShifts'] ?? 0}',
                    Icons.analytics_rounded,
                    const Color(0xFF2196F3),
                    (_todayStats['overview']?['totalShifts'] ?? 0) / 50.0, // Progress out of 50
                    'All time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Additional dashboard stats row
            Row(
              children: [
                Expanded(
                  child: _buildEnhancedStatCard(
                    'Total Alerts',
                    '${_todayStats['alerts']?['totalAlerts'] ?? 0}',
                    Icons.warning_rounded,
                    Colors.red,
                    (_todayStats['alerts']?['totalAlerts'] ?? 0) / 10.0, // Progress out of 10
                    'All types',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnhancedStatCard(
                    'Avg Duty Hours',
                    '${(_todayStats['dutyHours']?['averageHours'] ?? 0.0).toStringAsFixed(1)}h',
                    Icons.schedule_rounded,
                    const Color(0xFF9C27B0),
                    ((_todayStats['dutyHours']?['averageHours'] ?? 0.0) / 12.0).clamp(0.0, 1.0), // Progress out of 12 hours
                    'Average',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnhancedStatCard(
                    'Staff On Duty',
                    '${_todayStats['staff']?['onDuty'] ?? 0}',
                    Icons.people_rounded,
                    const Color(0xFF607D8B),
                    (_todayStats['staff']?['onDuty'] ?? 0) / (_todayStats['staff']?['total'] ?? 1).toDouble(), // Progress out of total staff
                    'Active now',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDutyTrendChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _isDarkMode ? AppTheme.cardBackground : AppTheme.lightCardBackground,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode ? [
                  AppTheme.primaryNavy,
                  const Color(0xFF2A3441),
                ] : [
                  AppTheme.accentOrange,
                  AppTheme.accentOrange.withOpacity(0.8),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isDarkMode ? AppTheme.accentOrange : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: _isDarkMode ? AppTheme.accentOrange : Colors.white,
                            child: Text(
                              _getInitials(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _isDarkMode ? Colors.white : AppTheme.accentOrange,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sectionInfo['inchargeName'] ?? 'Section Incharge',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _sectionInfo['inchargeId'] ?? 'SI001',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: _isDarkMode ? AppTheme.accentOrange : Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(_isDarkMode ? 0.1 : 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(_isDarkMode ? 0.2 : 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _sectionInfo['sectionName'] ?? 'Railway Section',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ONLINE',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'v1.0.4',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard, color: AppTheme.accentOrange),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person, color: AppTheme.accentOrange),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment, color: AppTheme.accentOrange),
                  title: const Text('Duty Records'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DutiesScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics, color: AppTheme.accentOrange),
                  title: const Text('Reports'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportsScreen(),
                      ),
                    );
                  },
                ),
                // User Management - Only for SUPERADMIN
                if (_authService.currentUser?.role == UserRole.SUPERADMIN) ...[
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings, color: AppTheme.accentOrange),
                    title: const Text('User Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserManagementScreen(),
                        ),
                      );
                    },
                  ),
                ],
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings, color: AppTheme.accentOrange),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help, color: AppTheme.accentOrange),
                  title: const Text('Help & Support'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Dark Mode Toggle
          Container(
            padding: const EdgeInsets.fromLTRB(16,8,16,8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: _isDarkMode ? Colors.white.withOpacity(0.1) : AppTheme.lightDividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: AppTheme.accentOrange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Dark Mode',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _isDarkMode ? Colors.white : AppTheme.lightTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _isDarkMode,
                  onChanged: (value) {
                    _toggleTheme();
                  },
                  activeColor: AppTheme.accentOrange,
                  activeTrackColor: AppTheme.accentOrange.withOpacity(0.3),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.grey.withOpacity(0.3),
                ),
              ],
            ),
          ),
          // Logout Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Logout',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                Navigator.pop(context); // Close drawer first
                
                // Show enhanced logout confirmation dialog
                final shouldLogout = await _showLogoutDialog();
                
                if (shouldLogout == true) {
                  // Perform logout
                  await _authService.logout();
                  
                  if (mounted) {
                    // Navigate to login screen
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ),
          // Version info at bottom
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(),

                Row(
                  children: [
                    const Icon(Icons.train, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'DutyHours v1.0.4',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    // Update the global theme
    RailShiftManagerApp.isDarkMode.value = _isDarkMode;
  }

  void _showCreateDutyDialog() {
    print('🚂 Opening create duty dialog...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CreateDutyDialog(
          crewMembers: _crewMembers,
          sectionInfo: _sectionInfo,
          onDutyCreated: () {
            print('✅ Duty created successfully, refreshing data...');
            _loadData();
          },
        );
      },
    );
  }

  Future<bool?> _showLogoutDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon and title
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sign Out',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to sign out of your account?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _isDarkMode ? AppTheme.textSecondary : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ll need to sign in again to access your duties.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isDarkMode ? AppTheme.textSecondary : Colors.grey.shade500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 32),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: _isDarkMode ? AppTheme.borderColor : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _isDarkMode ? AppTheme.textPrimary : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getInitials() {
    final name = _sectionInfo['inchargeName'] ?? 'Section Incharge';
    if (name.isEmpty) return 'SI';
    
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    }
  }



}
