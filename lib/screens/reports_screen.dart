import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/crew_member.dart';
import '../models/duty_assignment.dart';
import '../services/database_service.dart';
import '../services/shift_service.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final ShiftService _shiftService = ShiftService();
  final DashboardService _dashboardService = DashboardService();
  
  List<CrewMember> _crewMembers = [];
  bool _isLoading = true;
  bool _isDarkMode = true;
  
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Analytics data from API
  Map<String, dynamic> _statisticsData = {};
  List<Map<String, dynamic>> _trendPoints = [];

  @override
  void initState() {
    super.initState();
    _isDarkMode = RailShiftManagerApp.isDarkMode.value;
    _tabController = TabController(length: 2, vsync: this); // Changed from 3 to 2
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load local data for backward compatibility
      final crewMembers = await _dbService.getCrewMembers();
      
      // Try to fetch statistics from API
      Map<String, dynamic> statisticsData = {};
      List<Map<String, dynamic>> trendPoints = [];
      try {
        final statisticsResponse = await _shiftService.getShiftStatistics();
        statisticsData = statisticsResponse['data'] ?? {};
      } catch (statsError) {
        print('⚠️ Failed to fetch statistics for reports, using empty data: $statsError');
        // Continue with empty stats - the UI will handle this gracefully
      }

      // Fetch trend data from dashboard API for Trends tab.
      try {
        final trendsResponse = await _dashboardService.getShiftTrends(days: 7);
        final trendsData = trendsResponse['data'] as Map<String, dynamic>? ?? {};
        trendPoints = List<Map<String, dynamic>>.from(trendsData['trends'] ?? []);
      } catch (trendError) {
        print('⚠️ Failed to fetch dashboard trends, using computed fallback: $trendError');
      }
      
      setState(() {
        _crewMembers = crewMembers;
        _statisticsData = statisticsData;
        _trendPoints = trendPoints;
        _isLoading = false;
      });
      
      _animationController.forward();
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

  // Helper method to safely parse integer values from API response
  int _parseIntValue(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) return value.round();
    return 0;
  }

  // Helper method to safely parse double values from API response
  double _parseDoubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> get _analyticsData {
    // Map API statistics data to the format expected by the UI
    if (_statisticsData.isEmpty && _trendPoints.isEmpty) {
      // Return default empty data structure
      return {
        'totalShifts': 0,
        'activeShifts': 0,
        'completedShifts': 0,
        'cancelledShifts': 0,
        'averageDutyHours': 0.0,
        'avgDurationHours': 0.0,
        'activeDuties': 0,
        'completedDuties': 0,
        'scheduledDuties': 0,
        'reliefPlannedDuties': 0,
        'cancelledDuties': 0,
        'overdueDuties': 0,
        'dutiesLast7Days': 0,
        'dutiesLast30Days': 0,
        'onDutyCrew': 0,
        'availableCrew': _crewMembers.length,
        'utilizationRate': 0,
        'weeklyData': <String, int>{
          'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0,
        },
        'topRoutes': <MapEntry<String, int>>[],
        'byDutyType': <String, dynamic>{},
        'byStatus': <String, dynamic>{},
        'bySection': <String, dynamic>{},
      };
    }
    
    final byStatus = _statisticsData['byStatus'] as Map<String, dynamic>? ?? {};
    final bySection = _statisticsData['bySection'] as Map<String, dynamic>? ?? {};
    final byDutyType = _statisticsData['byDutyType'] as Map<String, dynamic>? ?? {};
    
    int totalShifts = _parseIntValue(_statisticsData['totalShifts']);
    final weeklyData = _buildWeeklyData(totalShifts);
    if (totalShifts == 0 && _trendPoints.isNotEmpty) {
      totalShifts = weeklyData.values.fold(0, (sum, value) => sum + value);
    }
    
    final topRoutes = bySection.entries.map((e) => MapEntry(e.key, _parseIntValue(e.value))).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      'totalShifts': _parseIntValue(_statisticsData['totalShifts']),
      'activeShifts': _parseIntValue(_statisticsData['activeShifts']),
      'completedShifts': _parseIntValue(_statisticsData['completedShifts']),
      'cancelledShifts': _parseIntValue(_statisticsData['cancelledShifts']),
      'averageDutyHours': _parseDoubleValue(_statisticsData['averageDutyHours']),
      'activeDuties': _parseIntValue(byStatus['IN_PROGRESS']),
      'completedDuties': _parseIntValue(byStatus['COMPLETED']),
      'scheduledDuties': _parseIntValue(byStatus['SCHEDULED']),
      'reliefPlannedDuties': _parseIntValue(byStatus['RELIEF_PLANNED']),
      'cancelledDuties': _parseIntValue(byStatus['CANCELLED']),
      'overdueDuties': _parseIntValue(byStatus['CANCELLED']) + _parseIntValue(byStatus['RELIEF_PLANNED']),
      'dutiesLast7Days': (totalShifts * 0.2).round(), // Approximate
      'dutiesLast30Days': totalShifts,
      'onDutyCrew': _parseIntValue(_statisticsData['activeShifts']),
      'availableCrew': _crewMembers.length - _parseIntValue(_statisticsData['activeShifts']),
      'utilizationRate': _crewMembers.isNotEmpty 
          ? (_parseIntValue(_statisticsData['activeShifts']) / _crewMembers.length * 100).round() 
          : 0,
      'avgDurationHours': _parseDoubleValue(_statisticsData['averageDutyHours']),
      'weeklyData': weeklyData,
      'topRoutes': topRoutes.take(5).toList(),
      'byDutyType': byDutyType,
      'byStatus': byStatus,
      'bySection': bySection,
    };
  }

  Map<String, int> _buildWeeklyData(int totalShifts) {
    final weeklyData = <String, int>{
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    if (_trendPoints.isNotEmpty) {
      for (final point in _trendPoints) {
        final date = DateTime.tryParse(point['date']?.toString() ?? '');
        if (date == null) continue;

        final key = _weekdayLabel(date.weekday);
        final rawValue = point['total'] ?? point['shiftsCreated'] ?? 0;
        final value = rawValue is num
            ? rawValue.toInt()
            : int.tryParse(rawValue.toString()) ?? 0;
        weeklyData[key] = value;
      }
      return weeklyData;
    }

    // Fallback approximation when trends endpoint is unavailable.
    weeklyData['Mon'] = (totalShifts * 0.15).round();
    weeklyData['Tue'] = (totalShifts * 0.16).round();
    weeklyData['Wed'] = (totalShifts * 0.14).round();
    weeklyData['Thu'] = (totalShifts * 0.15).round();
    weeklyData['Fri'] = (totalShifts * 0.17).round();
    weeklyData['Sat'] = (totalShifts * 0.12).round();
    weeklyData['Sun'] = (totalShifts * 0.11).round();
    return weeklyData;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return 'Mon';
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () {
              // TODO: Export reports functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export functionality coming soon')),
              );
            },
            icon: const Icon(Icons.download),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overview'),
            Tab(icon: Icon(Icons.trending_up), text: 'Trends'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildTrendsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Key Metrics', Icons.dashboard),
          const SizedBox(height: 16),
          _buildMetricsGrid(),
          const SizedBox(height: 24),
          _buildSectionTitle('Duty Status Distribution', Icons.pie_chart),
          const SizedBox(height: 16),
          _buildStatusChart(),
          const SizedBox(height: 24),
          _buildSectionTitle('Popular Routes', Icons.route),
          const SizedBox(height: 16),
          _buildTopRoutes(),
          const SizedBox(height: 24),
          _buildSectionTitle('Duty Type Distribution', Icons.category),
          const SizedBox(height: 16),
          _buildDutyTypeChart(),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Weekly Activity', Icons.show_chart),
          const SizedBox(height: 16),
          _buildWeeklyChart(),
          const SizedBox(height: 24),
          _buildSectionTitle('Performance Insights', Icons.insights),
          const SizedBox(height: 16),
          _buildInsightsCards(),
          const SizedBox(height: 24),
          _buildSectionTitle('Operational Efficiency', Icons.speed),
          const SizedBox(height: 16),
          _buildEfficiencyMetrics(),
        ],
      ),
    );
  }



  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.accentOrange,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          'Total Shifts',
          '${_analyticsData['totalShifts']}',
          Icons.train,
          AppTheme.accentOrange,
          'All time',
        ),
        _buildMetricCard(
          'Active Shifts',
          '${_analyticsData['activeShifts']}',
          Icons.play_circle_filled,
          AppTheme.successGreen,
          'Currently running',
        ),
        _buildMetricCard(
          'Completed',
          '${_analyticsData['completedShifts']}',
          Icons.check_circle,
          Colors.blue,
          '${(_analyticsData['avgDurationHours'] as double? ?? 0.0).toStringAsFixed(1)}h avg',
        ),
        _buildMetricCard(
          'Cancelled',
          '${_analyticsData['cancelledShifts']}',
          Icons.cancel,
          AppTheme.errorRed,
          'Needs attention',
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.8),
          ] : [
            Colors.white,
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: color,
                  size: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart() {
    final byStatus = _analyticsData['byStatus'] as Map<String, dynamic>? ?? {};
    final total = _analyticsData['totalShifts'] as int? ?? 0;
    
    if (total == 0) {
      return _buildEmptyChart('No shift data available');
    }

    final scheduledCount = byStatus['SCHEDULED'] ?? 0;
    final inProgressCount = byStatus['IN_PROGRESS'] ?? 0;
    final completedCount = byStatus['COMPLETED'] ?? 0;
    final reliefPlannedCount = byStatus['RELIEF_PLANNED'] ?? 0;
    final cancelledCount = byStatus['CANCELLED'] ?? 0;

    final scheduledPercent = scheduledCount / total;
    final inProgressPercent = inProgressCount / total;
    final completedPercent = completedCount / total;
    final reliefPlannedPercent = reliefPlannedCount / total;
    final cancelledPercent = cancelledCount / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.8),
          ] : [
            Colors.white,
            Colors.grey.shade50,
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
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: StatusPieChartPainter(
                      scheduledPercent: scheduledPercent,
                      inProgressPercent: inProgressPercent,
                      completedPercent: completedPercent,
                      reliefPlannedPercent: reliefPlannedPercent,
                      cancelledPercent: cancelledPercent,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total.toString(),
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'Total Duties',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Scheduled', Colors.orange, '$scheduledCount'),
              _buildLegendItem('In Progress', AppTheme.successGreen, '$inProgressCount'),
              _buildLegendItem('Completed', Colors.blue, '$completedCount'),
              _buildLegendItem('Relief Planned', Colors.purple, '$reliefPlannedCount'),
              _buildLegendItem('Cancelled', AppTheme.errorRed, '$cancelledCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTopRoutes() {
    final routes = _analyticsData['topRoutes'] as List<MapEntry<String, int>>? ?? [];
    
    if (routes.isEmpty) {
      return _buildEmptyChart('No route data available');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.8),
          ] : [
            Colors.white,
            Colors.grey.shade50,
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
      ),
      child: Column(
        children: routes.asMap().entries.map((entry) {
          final index = entry.key;
          final route = entry.value;
          final maxValue = routes.first.value;
          final percentage = route.value / maxValue;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        route.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${route.value} duties',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: _isDarkMode 
                      ? AppTheme.surfaceColor 
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getRouteColor(index),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getRouteColor(int index) {
    final colors = [
      AppTheme.accentOrange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  Widget _buildDutyTypeChart() {
    final byDutyType = _analyticsData['byDutyType'] as Map<String, dynamic>? ?? {};
    
    if (byDutyType.isEmpty) {
      return _buildEmptyChart('No duty type data available');
    }

    final dutyTypes = byDutyType.entries.map((e) => MapEntry(e.key, _parseIntValue(e.value))).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.8),
          ] : [
            Colors.white,
            Colors.grey.shade50,
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
      ),
      child: Column(
        children: dutyTypes.asMap().entries.map((entry) {
          final index = entry.key;
          final dutyType = entry.value;
          final maxValue = dutyTypes.first.value;
          final percentage = dutyType.value / maxValue;
          
          String dutyTypeName;
          switch (dutyType.key) {
            case 'SP':
              dutyTypeName = 'Shunting Pilot';
              break;
            case 'WR':
              dutyTypeName = 'Wagon Repair';
              break;
            case 'LR':
              dutyTypeName = 'Locomotive Repair';
              break;
            default:
              dutyTypeName = dutyType.key;
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        dutyTypeName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${dutyType.value} shifts',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getDutyTypeColor(index),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: _isDarkMode 
                      ? AppTheme.surfaceColor 
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getDutyTypeColor(index),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getDutyTypeColor(int index) {
    final colors = [
      AppTheme.accentOrange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Widget _buildWeeklyChart() {
    final weeklyData = _analyticsData['weeklyData'] as Map<String, int>? ?? {};
    
    if (weeklyData.isEmpty) {
      return _buildEmptyChart('No weekly data available');
    }

    final maxValue = weeklyData.values.isEmpty ? 1 : weeklyData.values.reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.8),
          ] : [
            Colors.white,
            Colors.grey.shade50,
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
      ),
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyData.entries.map((entry) {
                final height = maxValue > 0 ? (entry.value / maxValue * 160) : 0.0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      entry.value.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.accentOrange,
                            AppTheme.accentOrange.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCards() {
    final completedShifts = _analyticsData['completedShifts'] as int? ?? 0;
    final totalShifts = _analyticsData['totalShifts'] as int? ?? 0;
    final completionRate = totalShifts > 0 ? ((completedShifts / totalShifts) * 100).round() : 0;
    
    final insights = [
      {
        'title': 'Completion Rate',
        'value': '$completionRate%',
        'description': 'Shifts completed successfully',
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'title': 'Average Duration',
        'value': '${(_analyticsData['avgDurationHours'] as double? ?? 0.0).toStringAsFixed(1)}h',
        'description': 'Per completed shift',
        'icon': Icons.schedule,
        'color': Colors.blue,
      },
      {
        'title': 'Active Shifts',
        'value': '${_analyticsData['activeShifts']}',
        'description': 'Currently in progress',
        'icon': Icons.trending_up,
        'color': AppTheme.accentOrange,
      },
    ];

    return Column(
      children: insights.map((insight) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDarkMode ? [
              AppTheme.cardBackground,
              AppTheme.cardBackground.withOpacity(0.8),
            ] : [
              Colors.white,
              (insight['color'] as Color).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (insight['color'] as Color).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (insight['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                insight['icon'] as IconData,
                color: insight['color'] as Color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    insight['title'] as String,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      insight['value'] as String,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: insight['color'] as Color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    insight['description'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildEfficiencyMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildEfficiencyCard(
            'On-Time Rate',
            '${_calculateOnTimeRate()}%',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildEfficiencyCard(
            'Delay Rate',
            '${_calculateDelayRate()}%',
            Icons.warning,
            AppTheme.errorRed,
          ),
        ),
      ],
    );
  }

  Widget _buildEfficiencyCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.8),
          ] : [
            Colors.white,
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }



  Widget _buildEmptyChart(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [
            AppTheme.cardBackground,
            AppTheme.cardBackground.withOpacity(0.8),
          ] : [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  int _calculateOnTimeRate() {
    final completed = _analyticsData['completedShifts'] as int? ?? 0;
    final total = _analyticsData['totalShifts'] as int? ?? 0;
    return total > 0 ? ((completed / total) * 100).round() : 0;
  }

  int _calculateDelayRate() {
    final cancelled = _analyticsData['cancelledShifts'] as int? ?? 0;
    final total = _analyticsData['totalShifts'] as int? ?? 0;
    return total > 0 ? ((cancelled / total) * 100).round() : 0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class StatusPieChartPainter extends CustomPainter {
  final double scheduledPercent;
  final double inProgressPercent;
  final double completedPercent;
  final double reliefPlannedPercent;
  final double cancelledPercent;

  StatusPieChartPainter({
    required this.scheduledPercent,
    required this.inProgressPercent,
    required this.completedPercent,
    required this.reliefPlannedPercent,
    required this.cancelledPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final scheduledPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    final inProgressPaint = Paint()
      ..color = AppTheme.successGreen
      ..style = PaintingStyle.fill;

    final completedPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final reliefPlannedPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    final cancelledPaint = Paint()
      ..color = AppTheme.errorRed
      ..style = PaintingStyle.fill;

    double startAngle = -math.pi / 2;

    // Draw scheduled slice
    if (scheduledPercent > 0) {
      final scheduledAngle = 2 * math.pi * scheduledPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        scheduledAngle,
        true,
        scheduledPaint,
      );
      startAngle += scheduledAngle;
    }

    // Draw in progress slice
    if (inProgressPercent > 0) {
      final inProgressAngle = 2 * math.pi * inProgressPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        inProgressAngle,
        true,
        inProgressPaint,
      );
      startAngle += inProgressAngle;
    }

    // Draw completed slice
    if (completedPercent > 0) {
      final completedAngle = 2 * math.pi * completedPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        completedAngle,
        true,
        completedPaint,
      );
      startAngle += completedAngle;
    }

    // Draw relief planned slice
    if (reliefPlannedPercent > 0) {
      final reliefPlannedAngle = 2 * math.pi * reliefPlannedPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        reliefPlannedAngle,
        true,
        reliefPlannedPaint,
      );
      startAngle += reliefPlannedAngle;
    }

    // Draw cancelled slice
    if (cancelledPercent > 0) {
      final cancelledAngle = 2 * math.pi * cancelledPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        cancelledAngle,
        true,
        cancelledPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}