import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shift_service.dart';
import '../services/notification_service.dart';
import '../models/alert.dart';
import '../theme/app_theme.dart';
import '../screens/duty_detail_screen.dart';
import '../models/duty_assignment.dart';
import '../widgets/alert_card.dart';

class AlertManagementScreen extends StatefulWidget {
  final String? shiftId;
  final String? initialShiftId;
  final String? initialAlertId;
  
  const AlertManagementScreen({
    super.key,
    this.shiftId,
    this.initialShiftId,
    this.initialAlertId,
  });

  @override
  State<AlertManagementScreen> createState() => _AlertManagementScreenState();
}

class _AlertManagementScreenState extends State<AlertManagementScreen> with TickerProviderStateMixin {
  final ShiftService _shiftService = ShiftService();
  final NotificationService _notificationService = NotificationService();
  
  List<Alert> _alerts = [];
  List<Alert> _pendingAlerts = [];
  bool _isLoading = false;
  String? _focusedShiftId;
  String? _focusedAlertId;
  AlertType? _selectedFilter;
  
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    // Set focused IDs from navigation
    _focusedShiftId = widget.initialShiftId ?? widget.shiftId;
    _focusedAlertId = widget.initialAlertId;
    
    _loadAlerts();
    
    // If we have a focused alert, show a notification that we're viewing it
    if (_focusedAlertId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFocusedAlertInfo();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {

    setState(() => _isLoading = true);
    
    try {
      // Try to load from backend first
      try {
        final pendingResponse = await _shiftService.getPendingAlerts();
        final pendingAlertsData = pendingResponse['data'] as List? ?? [];
        

        
        _pendingAlerts = pendingAlertsData
            .map((alertData) => Alert.fromJson(alertData))
            .where((alert) => alert.shift?.status == 'IN_PROGRESS') // Filter locally
            .toList();
            


        if (widget.shiftId != null) {
          final shiftResponse = await _shiftService.getShiftAlerts(widget.shiftId!);
          final shiftAlertsData = shiftResponse['data'] as List? ?? [];
            print('📥 Shift alerts loaded: ${shiftAlertsData.length}');
          
          _alerts = shiftAlertsData
              .map((alertData) => Alert.fromJson(alertData))
              .toList();
        } else {
          _alerts = _pendingAlerts;
        }
      } catch (e) {
        print('Backend alerts not available: $e');
        _alerts = [];
        _pendingAlerts = [];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load alerts from server'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
      
      _fadeController.forward();
      
    } catch (e) {
      print('Error in _loadAlerts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  void _showFocusedAlertInfo() {
    if (_focusedAlertId == null) return;
    
    final focusedAlert = _alerts.firstWhere(
      (alert) => alert.id == _focusedAlertId,
      orElse: () => _pendingAlerts.firstWhere(
        (alert) => alert.id == _focusedAlertId,
        orElse: () => Alert(
          id: _focusedAlertId!,
          shiftId: _focusedShiftId ?? 'unknown',
          type: AlertType.UNKNOWN,
          title: 'Alert',
          message: 'Alert details not found',
          sentAt: DateTime.now(),
          status: AlertStatus.PENDING,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.notifications_active, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Viewing ${focusedAlert.typeDisplayName} from notification'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.shiftId != null ? 'Shift Alerts' : 'Alert Management',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1A1F2E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _loadAlerts,
              icon: AnimatedRotation(
                turns: _isLoading ? 1 : 0,
                duration: const Duration(milliseconds: 1000),
                child: const Icon(Icons.refresh_rounded),
              ),
              tooltip: 'Refresh Alerts',
              style: IconButton.styleFrom(
                backgroundColor: isDarkMode 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        bottom: widget.shiftId == null ? PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1A1F2E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.accentOrange,
              unselectedLabelColor: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
              indicatorColor: AppTheme.accentOrange,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.priority_high, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('Pending'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.history, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('All Alerts'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ) : null,
      ),
      body: _isLoading 
        ? _buildLoadingState()
        : widget.shiftId != null 
          ? _buildShiftAlertsView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingAlertsView(),
                _buildAllAlertsView(),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode 
                ? Colors.white.withOpacity(0.05) 
                : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading alerts...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftAlertsView() {
    final filteredAlerts = _getFilteredAlerts(_alerts);

    if (_alerts.isEmpty) {
      return _buildEmptyState('No alerts for this shift', Icons.shield_outlined);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadAlerts,
        color: AppTheme.accentOrange,
        child: Column(
          children: [
            _buildFilterChips(),
            if (filteredAlerts.isEmpty)
              Expanded(child: _buildEmptyState('No alerts match filter', Icons.filter_alt_off_outlined))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredAlerts.length,
                  itemBuilder: (context, index) {
                    final alertItem = filteredAlerts[index];
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      child: AlertCard(
                        alert: alertItem,
                        isDarkMode: Theme.of(context).brightness == Brightness.dark,
                        timeAgo: _getTimeAgo(alertItem.sentAt),
                        formattedDateTime: _formatDateTime(alertItem.sentAt),
                        onTap: () => _showEnhancedAlertDetails(alertItem),
                        onAcknowledge: () => _acknowledgeAlert(alertItem),
                        onViewShift: () {
                          final shiftRef = alertItem.shift;
                          final dummyDuty = DutyAssignment(
                            id: alertItem.shiftId,
                            backendShiftId: alertItem.shiftId,
                            trainNumber: shiftRef?.trainNumber ?? alertItem.shiftId.split('_').last,
                            startTime: shiftRef?.signOnDateTime,
                            createdAt: DateTime.now(),
                            createdBy: 'system',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DutyDetailScreen(
                                duty: dummyDuty,
                                crewMembers: const [],
                              ),
                            ),
                          ).then((_) {
                            _loadAlerts();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingAlertsView() {
    // Include both PENDING and SENT alerts as they both require attention
    final pendingAlerts = _pendingAlerts.where((alert) => alert.isPending).toList();
    final filteredAlerts = _getFilteredAlerts(pendingAlerts);

    // Sort so most recent ones are at the top
    filteredAlerts.sort((a, b) => b.sentAt.compareTo(a.sentAt));

    if (pendingAlerts.isEmpty) {
      return _buildEmptyState('No pending alerts', Icons.check_circle_outline);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadAlerts,
        color: AppTheme.accentOrange,
        child: Column(
          children: [
            _buildAlertSummaryCard(pendingAlerts),
            _buildFilterChips(),
            if (filteredAlerts.isEmpty)
              Expanded(child: _buildEmptyState('No alerts match filter', Icons.filter_alt_off_outlined))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredAlerts.length,
                  itemBuilder: (context, index) {
                    final alertItem = filteredAlerts[index];
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      child: AlertCard(
                        alert: alertItem,
                        isDarkMode: Theme.of(context).brightness == Brightness.dark,
                        timeAgo: _getTimeAgo(alertItem.sentAt),
                        formattedDateTime: _formatDateTime(alertItem.sentAt),
                        onTap: () => _showEnhancedAlertDetails(alertItem),
                        onAcknowledge: () => _acknowledgeAlert(alertItem),
                        onViewShift: () {
                          final shiftRef = alertItem.shift;
                          final dummyDuty = DutyAssignment(
                            id: alertItem.shiftId,
                            backendShiftId: alertItem.shiftId,
                            trainNumber: shiftRef?.trainNumber ?? alertItem.shiftId.split('_').last,
                            startTime: shiftRef?.signOnDateTime,
                            createdAt: DateTime.now(),
                            createdBy: 'system',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DutyDetailScreen(
                                duty: dummyDuty,
                                crewMembers: const [],
                              ),
                            ),
                          ).then((_) {
                            _loadAlerts();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllAlertsView() {
    final filteredAlerts = _getFilteredAlerts(_pendingAlerts);

    if (_pendingAlerts.isEmpty) {
      return _buildEmptyState('No alerts found', Icons.notifications_none_outlined);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadAlerts,
        color: AppTheme.accentOrange,
        child: Column(
          children: [
            _buildAlertSummaryCard(_pendingAlerts),
            _buildFilterChips(),
            if (filteredAlerts.isEmpty)
              Expanded(child: _buildEmptyState('No alerts match filter', Icons.filter_alt_off_outlined))
            else
              Expanded(child: _buildGroupedAlertsList(filteredAlerts)),
          ],
        ),
      ),
    );
  }

  List<Alert> _getFilteredAlerts(List<Alert> alerts) {
    if (_selectedFilter == null) return alerts;
    return alerts.where((a) => a.type == _selectedFilter).toList();
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', null),
          const SizedBox(width: 8),
          _buildFilterChip('8 Hr', AlertType.DUTY_8HR),
          const SizedBox(width: 8),
          _buildFilterChip('10 Hr', AlertType.DUTY_10HR),
          const SizedBox(width: 8),
          _buildFilterChip('12 Hr', AlertType.DUTY_12HR),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, AlertType? filterType) {
    final isSelected = _selectedFilter == filterType;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = filterType);
        }
      },
      selectedColor: AppTheme.accentOrange.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accentOrange : (isDarkMode ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.accentOrange : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildGroupedAlertsList(List<Alert> alerts) {
    final groupedAlerts = <String, List<Alert>>{};
    for (final alert in alerts) {
      final key = alert.shiftId;
      groupedAlerts.putIfAbsent(key, () => []).add(alert);
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: groupedAlerts.length,
      itemBuilder: (context, index) {
        final shiftId = groupedAlerts.keys.elementAt(index);
        final shiftAlerts = groupedAlerts[shiftId]!;
        final firstAlert = shiftAlerts.first;
        final trainNumber = firstAlert.shift?.trainNumber ?? 'Unknown Train';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 24, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2F3E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentOrange.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.train_outlined, color: AppTheme.accentOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Train $trainNumber',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Shift ID: ${shiftId.length > 8 ? '${shiftId.substring(0, 8)}...' : shiftId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...shiftAlerts.asMap().entries.map((entry) {
              final alertItem = entry.value;
              return AnimatedContainer(
                duration: Duration(milliseconds: 300 + (entry.key * 100)),
                curve: Curves.easeOutCubic,
                child: AlertCard(
                  alert: alertItem,
                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                  timeAgo: _getTimeAgo(alertItem.sentAt),
                  formattedDateTime: _formatDateTime(alertItem.sentAt),
                  onTap: () => _showEnhancedAlertDetails(alertItem),
                  onAcknowledge: () => _acknowledgeAlert(alertItem),
                  onViewShift: () {
                    final shiftRef = alertItem.shift;
                    final dummyDuty = DutyAssignment(
                      id: alertItem.shiftId,
                      backendShiftId: alertItem.shiftId,
                      trainNumber: shiftRef?.trainNumber ?? alertItem.shiftId.split('_').last,
                      startTime: shiftRef?.signOnDateTime,
                      createdAt: DateTime.now(),
                      createdBy: 'system',
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DutyDetailScreen(
                          duty: dummyDuty,
                          crewMembers: const [],
                        ),
                      ),
                    ).then((_) {
                      _loadAlerts();
                    });
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildAlertSummaryCard(List<Alert> alerts) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pendingCount = alerts.where((a) => a.status == AlertStatus.PENDING).length;
    final criticalCount = alerts.where((a) => 
      a.type == AlertType.DUTY_10HR || a.type == AlertType.DUTY_12HR).length;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode 
            ? [const Color(0xFF1A1F2E), const Color(0xFF2A2F3E)]
            : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.3)
              : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.accentOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Current status overview',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Alerts',
                  alerts.length.toString(),
                  Icons.notifications_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'Pending',
                  pendingCount.toString(),
                  Icons.pending_outlined,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'Critical',
                  criticalCount.toString(),
                  Icons.warning_outlined,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDarkMode 
                ? Colors.white.withOpacity(0.05) 
                : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              size: 64,
              color: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All clear! No immediate attention required.',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white.withOpacity(0.4) : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }



  void _showEnhancedAlertDetails(Alert alert) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode 
                ? [const Color(0xFF1A1F2E), const Color(0xFF2A2F3E)]
                : [Colors.white, const Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getAlertColor(alert.type).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getAlertIcon(alert.type),
                        color: _getAlertColor(alert.type),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        alert.typeDisplayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: isDarkMode 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Status', alert.statusDisplayName, Icons.info_outline),
                const SizedBox(height: 12),
                _buildDetailRow('Message', alert.message, Icons.message_outlined),
                const SizedBox(height: 12),
                _buildDetailRow('Sent', _formatDateTime(alert.sentAt), Icons.schedule_outlined),
                if (alert.acknowledgedAt != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Acknowledged', _formatDateTime(alert.acknowledgedAt!), Icons.check_circle_outlined),
                ],
                if (alert.responseAction != null) ...[
                  const SizedBox(height: 20),
                  Divider(color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'Response Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Action', alert.responseAction!, Icons.reply_outlined),
                ],
                const SizedBox(height: 24),
                if (alert.status == AlertStatus.PENDING)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _acknowledgeAlert(alert);
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Acknowledge'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            
                            final shiftRef = alert.shift;
                            final dummyDuty = DutyAssignment(
                              id: alert.shiftId,
                              backendShiftId: alert.shiftId,
                              trainNumber: shiftRef?.trainNumber ?? alert.shiftId.split('_').last,
                              startTime: shiftRef?.signOnDateTime,
                              createdAt: DateTime.now(),
                              createdBy: 'system',
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DutyDetailScreen(
                                  duty: dummyDuty,
                                  crewMembers: const [],
                                ),
                              ),
                            ).then((_) {
                              _loadAlerts();
                            });
                          },
                          icon: const Icon(Icons.visibility_rounded),
                          label: const Text('View Shift'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode 
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  Color _getAlertColor(AlertType type) {
    switch (type) {
      case AlertType.DUTY_8HR:
        return const Color(0xFFF59E0B);
      case AlertType.DUTY_10HR:
        return const Color(0xFFDC2626);
      case AlertType.DUTY_12HR:
        return const Color(0xFF7F1D1D);
      case AlertType.RELIEF_PLANNED:
        return const Color(0xFF7C3AED);
      case AlertType.SHIFT_COMPLETED:
        return const Color(0xFF059669);
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.DUTY_8HR:
        return Icons.schedule_outlined;
      case AlertType.DUTY_10HR:
        return Icons.error_outline;
      case AlertType.DUTY_12HR:
        return Icons.report_problem_outlined;
      case AlertType.RELIEF_PLANNED:
        return Icons.directions_run_outlined;
      case AlertType.SHIFT_COMPLETED:
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _acknowledgeAlert(Alert alert) async {
    try {
      print('✅ Acknowledge button tapped for alert ${alert.id} | shift: ${alert.shiftId} | type: ${alert.type.alertResponseApiValue}');
      HapticFeedback.lightImpact();
      
      await _shiftService.acknowledgeAlert(
        shiftId: alert.shiftId,
        alertType: alert.type.alertResponseApiValue,
      );
      
      // Update local state to reflect acknowledged status
      setState(() {
        final index = _pendingAlerts.indexWhere((a) => a.id == alert.id);
        if (index != -1) {
          _pendingAlerts[index] = _pendingAlerts[index].copyWith(
            status: AlertStatus.ACKNOWLEDGED,
            acknowledgedAt: DateTime.now(),
          );
        }
      });
      
      // Send notification about the response
      await _notificationService.sendAlertResponseNotification(
        shiftId: alert.shiftId,
        alertType: alert.typeDisplayName,
        response: 'ACKNOWLEDGED',
        trainNumber: 'Train ${alert.shiftId.split('_').last}', // Extract train number from shift ID
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Alert acknowledged successfully')),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }



  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// Enhanced Alert Response Dialog
class EnhancedAlertResponseDialog extends StatefulWidget {
  final Alert alert;
  final VoidCallback onResponseSubmitted;
  
  const EnhancedAlertResponseDialog({
    super.key,
    required this.alert,
    required this.onResponseSubmitted,
  });

  @override
  State<EnhancedAlertResponseDialog> createState() => _EnhancedAlertResponseDialogState();
}

class _EnhancedAlertResponseDialogState extends State<EnhancedAlertResponseDialog> with TickerProviderStateMixin {
  final ShiftService _shiftService = ShiftService();
  final _messageController = TextEditingController();
  
  AlertResponseType _selectedType = AlertResponseType.ACKNOWLEDGE;
  bool _isLoading = false;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode 
                ? [const Color(0xFF1A1F2E), const Color(0xFF2A2F3E)]
                : [Colors.white, const Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.reply_rounded,
                        color: AppTheme.accentOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Respond to Alert',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            widget.alert.typeDisplayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Response Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode 
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode 
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonFormField<AlertResponseType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    dropdownColor: isDarkMode ? const Color(0xFF2A2F3E) : Colors.white,
                    items: AlertResponseType.values.map((type) {
                      IconData getIcon() {
                        switch (type) {
                          case AlertResponseType.ACKNOWLEDGE:
                            return Icons.check_circle_outline;
                          case AlertResponseType.RELIEF_REQUESTED:
                            return Icons.swap_horiz;
                          case AlertResponseType.CONTINUING_DUTY:
                            return Icons.trending_up;
                          case AlertResponseType.ESCALATE:
                            return Icons.priority_high;
                          case AlertResponseType.RESOLVED:
                            return Icons.check_circle;
                        }
                      }
                      
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(getIcon(), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              type.toString().split('.').last.replaceAll('_', ' '),
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Response Message',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode 
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode 
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter your response message...',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white.withOpacity(0.4) : Colors.black38,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 4,
                    minLines: 3,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode 
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitResponse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Submit Response'),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitResponse() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_outlined, color: Colors.white),
              SizedBox(width: 8),
              Text('Please enter a response message'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // alertResponseApiValue maps DUTY_8HR→'8HR' etc. to match what
      // POST /shifts/:id/alert-response expects (different from GET /alerts type names).
      final alertType = widget.alert.type.alertResponseApiValue;
      final responseMessage = _messageController.text.trim();
      print('📨 Submit Response tapped for alert ${widget.alert.id} | shift: ${widget.alert.shiftId}');
      print('  - Alert type (response API): $alertType');
      print('  - Response type: ${_selectedType.toString().split('.').last}');
      print('  - Message: $responseMessage');

      switch (_selectedType) {
        case AlertResponseType.ACKNOWLEDGE:
          await _shiftService.acknowledgeAlert(
            shiftId: widget.alert.shiftId,
            alertType: alertType,
            remarks: responseMessage,
          );
          break;
        case AlertResponseType.RELIEF_REQUESTED:
          await _shiftService.requestRelief(
            shiftId: widget.alert.shiftId,
            alertType: alertType,
            reason: responseMessage,
          );
          break;
        case AlertResponseType.CONTINUING_DUTY:
          await _shiftService.continueDuty(
            shiftId: widget.alert.shiftId,
            alertType: alertType,
            justification: responseMessage,
          );
          break;
        case AlertResponseType.ESCALATE:
          await _shiftService.escalateAlert(
            shiftId: widget.alert.shiftId,
            alertType: alertType,
            escalationReason: responseMessage,
          );
          break;
        case AlertResponseType.RESOLVED:
          await _shiftService.resolveAlert(
            shiftId: widget.alert.shiftId,
            alertType: alertType,
            resolution: responseMessage,
          );
          break;
      }

      if (mounted) {
        Navigator.pop(context);
        HapticFeedback.lightImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Response submitted successfully')),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        
        widget.onResponseSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

