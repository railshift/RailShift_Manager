import 'package:flutter/material.dart';
import '../models/crew_member.dart';
import '../models/duty_assignment.dart';
import '../models/staff.dart';
import '../services/database_service.dart';
import '../services/shift_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'duty_detail_screen.dart';
import 'alert_management_screen.dart';

class DutiesScreen extends StatefulWidget {
  const DutiesScreen({super.key});

  @override
  State<DutiesScreen> createState() => _DutiesScreenState();
}

class _DutiesScreenState extends State<DutiesScreen> {
  final DatabaseService _dbService = DatabaseService();
  final ShiftService _shiftService = ShiftService();
  final TextEditingController _searchController = TextEditingController();
  
  List<DutyAssignment> _allDuties = [];
  List<DutyAssignment> _filteredDuties = [];
  List<CrewMember> _crewMembers = [];
  dynamic _shiftsData = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isDarkMode = true;
  String _selectedFilter = 'All';
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMoreData = true;
  
  final List<String> _filterOptions = ['All', 'Scheduled', 'In Progress', 'Completed', 'Relief Planned', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _isDarkMode = RailShiftManagerApp.isDarkMode.value;
    _loadData();
  }

  Future<void> _loadActiveShifts() async {
    setState(() => _isLoading = true);
    
    try {
      final activeShiftsResponse = await _shiftService.getActiveShifts();
      final crewMembers = await _dbService.getCrewMembers();
      
      // Safely extract active shifts data
      List<dynamic> activeShifts = [];
      final responseData = activeShiftsResponse['data'];
      if (responseData is Map<String, dynamic> && responseData['activeShifts'] is List) {
        activeShifts = responseData['activeShifts'] as List;
      } else if (responseData is List) {
        activeShifts = responseData;
      }
      
      final activeDuties = activeShifts.map((shiftData) => _convertActiveShiftToDuty(shiftData)).toList();
      
      setState(() {
        _allDuties = activeDuties;
        _crewMembers = crewMembers;
        _shiftsData = responseData; // Use the already extracted responseData
        _isLoading = false;
      });
      
      _filterDuties();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading active shifts: $e')),
        );
      }
    }
  }

  // Helper method to safely convert values to double
  double _safeDoubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper method to safely convert values to bool
  bool? _safeBoolValue(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    if (value is int) return value != 0;
    return null;
  }

  DutyAssignment _convertActiveShiftToDuty(Map<String, dynamic> shiftData) {
    // Safely extract trainManager
    Map<String, dynamic>? trainManager;
    try {
      final tmData = shiftData['trainManager'];
      if (tmData is Map<String, dynamic>) {
        trainManager = tmData;
      } else if (tmData is List && tmData.isNotEmpty && tmData.first is Map<String, dynamic>) {
        trainManager = tmData.first as Map<String, dynamic>;
      }
    } catch (e) {
      trainManager = null;
    }
    
    return DutyAssignment(
      id: shiftData['id'],
      trainNumber: shiftData['trainNumber'] ?? '',
      guardId: trainManager?['id'] ?? '',
      assistantId: null,
      startTime: DateTime.parse(shiftData['signOnDateTime'] ?? shiftData['signOnTime'] ?? DateTime.now().toIso8601String()),
      endTime: null, // Active shifts don't have end time
      fromStation: 'Active',
      toStation: 'In Progress',
      status: ShiftStatus.IN_PROGRESS,
      notes: 'Current duty hours: ${_safeDoubleValue(shiftData['currentDutyHours']).toStringAsFixed(1)}h',
      createdAt: DateTime.parse(shiftData['signOnDateTime'] ?? shiftData['signOnTime'] ?? DateTime.now().toIso8601String()),
      createdBy: 'system',
    );
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
      _currentPage = 1;
    }
    
    try {
      // Get status filter for API
      String? statusFilter;
      if (_selectedFilter != 'All') {
        switch (_selectedFilter) {
          case 'Scheduled':
            statusFilter = 'SCHEDULED';
            break;
          case 'In Progress':
            statusFilter = 'IN_PROGRESS';
            break;
          case 'Completed':
            statusFilter = 'COMPLETED';
            break;
          case 'Relief Planned':
            statusFilter = 'RELIEF_PLANNED';
            break;
          case 'Cancelled':
            statusFilter = 'CANCELLED';
            break;
        }
      }

      // Fetch shifts from API
      final shiftsResponse = await _shiftService.getAllShifts(
        status: statusFilter,
        page: _currentPage,
        limit: 20,
      );

      // Load crew members from local database for now
      final crewMembers = await _dbService.getCrewMembers();
      
      // Convert API shifts to DutyAssignment objects
      final responseData = shiftsResponse['data'];
      
      List<dynamic> shifts;
      Map<String, dynamic>? pagination;
      
      // Actual API: data is a direct array, pagination is top-level sibling
      if (responseData is List) {
        shifts = responseData;
        pagination = shiftsResponse['pagination'] as Map<String, dynamic>?;
      } else if (responseData is Map<String, dynamic>) {
        // Routes-doc format: data.shifts + data.pagination
        shifts = responseData['shifts'] as List? ?? [];
        pagination = responseData['pagination'] as Map<String, dynamic>?;
      } else {
        shifts = [];
        pagination = null;
      }
      
      final newDuties = <DutyAssignment>[];
      for (int i = 0; i < shifts.length; i++) {
        try {
          final shiftItem = shifts[i];
          print('🔍 Shift $i type: ${shiftItem.runtimeType}');
          
          if (shiftItem is Map<String, dynamic>) {
            final duty = _convertShiftToDuty(shiftItem);
            newDuties.add(duty);
          } else {
            print('⚠️ Skipping shift $i - not a Map: $shiftItem');
          }
        } catch (e) {
          print('❌ Error converting shift $i: $e');
        }
      }

      setState(() {
        if (loadMore) {
          _allDuties.addAll(newDuties);
        } else {
          _allDuties = [...newDuties];
        }
        _crewMembers = crewMembers;
        _shiftsData = responseData;
        _currentPage = pagination?['page'] ?? 1;
        _totalPages = pagination?['pages'] ?? pagination?['totalPages'] ?? 1;
        _hasMoreData = _currentPage < _totalPages;
        _isLoading = false;
        _isLoadingMore = false;
      });
      
      _filterDuties();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading duties: $e')),
        );
      }
    }
  }

  DutyAssignment _convertShiftToDuty(Map<String, dynamic> shiftData) {
    try {

      
      // Convert API shift data to DutyAssignment model
      // Safely extract nested objects, handling both Map and List cases
      Map<String, dynamic>? trainManager;
      Map<String, dynamic>? locoPilot;
      
      try {
        final tmData = shiftData['trainManager'];
        if (tmData is Map<String, dynamic>) {
          trainManager = tmData;
        } else if (tmData is List && tmData.isNotEmpty && tmData.first is Map<String, dynamic>) {
          trainManager = tmData.first as Map<String, dynamic>;
        }
      } catch (e) {
        print('⚠️ Error extracting trainManager: $e');
        trainManager = null;
      }
      
      try {
        final lpData = shiftData['locoPilot'];
        if (lpData is Map<String, dynamic>) {
          locoPilot = lpData;
        } else if (lpData is List && lpData.isNotEmpty && lpData.first is Map<String, dynamic>) {
          locoPilot = lpData.first as Map<String, dynamic>;
        }
      } catch (e) {
        print('⚠️ Error extracting locoPilot: $e');
        locoPilot = null;
      }
      
      // Map API status to ShiftStatus
      ShiftStatus status;
      switch (shiftData['status']?.toString()) {
        case 'SCHEDULED':
          status = ShiftStatus.SCHEDULED;
          break;
        case 'IN_PROGRESS':
          status = ShiftStatus.IN_PROGRESS;
          break;
        case 'COMPLETED':
          status = ShiftStatus.COMPLETED;
          break;
        case 'RELIEF_PLANNED':
          status = ShiftStatus.RELIEF_PLANNED;
          break;
        case 'CANCELLED':
          status = ShiftStatus.CANCELLED;
          break;
        default:
          status = ShiftStatus.SCHEDULED;
      }

      // Extract locomotive info safely
      Map<String, dynamic>? locomotive;
      try {
        final locoData = shiftData['locomotive'];
        if (locoData is Map<String, dynamic>) {
          locomotive = locoData;
        } else if (locoData is List && locoData.isNotEmpty && locoData.first is Map<String, dynamic>) {
          locomotive = locoData.first as Map<String, dynamic>;
        }
      } catch (e) {
        print('⚠️ Error extracting locomotive: $e');
        locomotive = null;
      }
      
      return DutyAssignment(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}_${shiftData['trainNumber']}', // Generate local ID
        backendShiftId: shiftData['id']?.toString(), // Store backend shift ID
        trainNumber: shiftData['trainNumber']?.toString() ?? '',
        trainName: shiftData['trainName']?.toString(),
        locomotiveNo: locomotive?['locomotiveNo']?.toString(),
        signOnStation: shiftData['signOnStation']?.toString() ?? 'Unknown',
        section: shiftData['section']?.toString() ?? shiftData['signOnStation']?.toString() ?? 'Unknown',
        dutyType: shiftData['dutyType']?.toString(),
        lobbySignOn: _safeBoolValue(shiftData['lobbySignOn']),
        trainArrivalDate: shiftData['trainArrivalDate'] != null 
            ? DateTime.tryParse(shiftData['trainArrivalDate'].toString()) 
            : null,
        trainArrivalTime: shiftData['trainArrivalDateTime'] != null 
            ? DateTime.tryParse(shiftData['trainArrivalDateTime'].toString()) 
            : null,
        signOnTime: shiftData['signOnDateTime'] != null 
            ? DateTime.tryParse(shiftData['signOnDateTime'].toString()) 
            : null,
        timeOfTO: shiftData['timeOfTO'] != null 
            ? DateTime.tryParse(shiftData['timeOfTO'].toString()) 
            : null,
        departureTime: shiftData['departureDateTime'] != null 
            ? DateTime.tryParse(shiftData['departureDateTime'].toString()) 
            : null,
        locoPilot: locoPilot != null ? CrewMemberInfo(
          employeeId: locoPilot['employeeId']?.toString() ?? '',
          name: locoPilot['name']?.toString() ?? '',
          phone: locoPilot['phone']?.toString() ?? '',
        ) : null,
        trainManager: trainManager != null ? CrewMemberInfo(
          employeeId: trainManager['employeeId']?.toString() ?? '',
          name: trainManager['name']?.toString() ?? '',
          phone: trainManager['phone']?.toString() ?? '',
        ) : null,
        guardId: shiftData['trainManagerId']?.toString() ?? '', // Use ID from API
        assistantId: null, // Not available in API response
        startTime: shiftData['signOnDateTime'] != null 
            ? DateTime.tryParse(shiftData['signOnDateTime'].toString()) ?? DateTime.now()
            : DateTime.now(),
        endTime: shiftData['signOffDateTime'] != null 
            ? DateTime.tryParse(shiftData['signOffDateTime'].toString()) 
            : null,
        fromStation: shiftData['signOnStation']?.toString() ?? 'Unknown',
        toStation: shiftData['signOffStation']?.toString() ?? (shiftData['section']?.toString() ?? 'In Progress'),
        status: status,
        notes: shiftData['reliefReason']?.toString(),
        createdAt: shiftData['createdAt'] != null 
            ? DateTime.tryParse(shiftData['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        createdBy: 'system',
      );
    } catch (e) {
      print('❌ Error converting shift data: $e');
      print('📄 Shift data: $shiftData');
      
      // Return a minimal duty assignment on error
      return DutyAssignment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        trainNumber: shiftData['trainNumber']?.toString() ?? 'Unknown',
        startTime: DateTime.now(),
        status: ShiftStatus.SCHEDULED,
        createdAt: DateTime.now(),
        createdBy: 'system',
        fromStation: 'Unknown',
        toStation: 'Unknown',
      );
    }
  }

  void _filterDuties() {
    setState(() {
      _filteredDuties = _allDuties.where((duty) {
        // Filter by search query (status filtering is now done at API level)
        bool searchMatch = true;
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          final guard = _crewMembers.where((c) => c.id == duty.guardId).firstOrNull;
          final pilot = _crewMembers.where((c) => c.id == duty.locoPilotId).firstOrNull;
          
          searchMatch = duty.trainNumber.toLowerCase().contains(query) ||
                       (guard?.name.toLowerCase().contains(query) ?? false) ||
                       (pilot?.name.toLowerCase().contains(query) ?? false) ||
                       (duty.fromStation?.toLowerCase().contains(query) ?? false) ||
                       (duty.toStation?.toLowerCase().contains(query) ?? false);
        }

        return searchMatch;
      }).toList();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _allDuties.clear();
      _filteredDuties.clear();
    });
    
    // Use active shifts API for "In Progress" filter
    if (filter == 'In Progress') {
      _loadActiveShifts();
    } else {
      _loadData(); // Reload data with new filter
    }
  }

  Future<void> _syncWithBackend() async {
    try {
      setState(() => _isLoading = true);
      
      // Show sync progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Syncing with backend...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Get local duties that don't have backend shift IDs
      final localDuties = await _dbService.getDutyAssignments();
      final dutiesNeedingSync = localDuties.where((duty) => 
        duty.backendShiftId == null && 
        duty.status != ShiftStatus.CANCELLED
      ).toList();
      
      print('🔄 Found ${dutiesNeedingSync.length} duties needing sync');
      
      int syncedCount = 0;
      
      // Try to match each local duty with a backend shift
      for (final duty in dutiesNeedingSync) {
        try {
          final matchingShift = await _shiftService.findShiftByTrainNumber(
            duty.trainNumber,
            date: duty.startTime,
          );
          
          if (matchingShift != null) {
            // Update local duty with backend shift ID
            final updatedDuty = duty.copyWith(
              backendShiftId: matchingShift['id'],
            );
            
            await _dbService.updateDutyAssignment(updatedDuty);
            syncedCount++;
            
            print('✅ Synced duty ${duty.trainNumber} with backend shift ${matchingShift['id']}');
          }
        } catch (e) {
          print('❌ Failed to sync duty ${duty.trainNumber}: $e');
        }
      }
      
      // Reload data to show updated sync status
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                ),
                const SizedBox(width: 8),
                Text('Sync complete: $syncedCount duties synced'),
              ],
            ),
            backgroundColor: AppTheme.successGreen.withOpacity(0.1),
          ),
        );
      }
      
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
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
        title: const Text('All Duties'),
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
            onPressed: _syncWithBackend,
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with Backend',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () {
                // Unfocus search field when tapping outside
                FocusScope.of(context).unfocus();
              },
              child: Column(
                children: [
                  _buildSearchAndFilter(),
                  _buildStatsHeader(),
                  Expanded(
                    child: _filteredDuties.isEmpty
                        ? _buildEmptyState()
                        : _buildDutiesList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : AppTheme.lightCardBackground,
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _filterDuties(),
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search duties, crew members, or stations...',
                hintStyle: TextStyle(
                  color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      _onFilterChanged(filter);
                    },
                    backgroundColor: _isDarkMode 
                        ? AppTheme.surfaceColor 
                        : Colors.grey.shade100,
                    selectedColor: AppTheme.accentOrange.withOpacity(0.2),
                    checkmarkColor: AppTheme.accentOrange,
                    labelStyle: TextStyle(
                      color: isSelected 
                          ? AppTheme.accentOrange 
                          : (_isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected 
                          ? AppTheme.accentOrange 
                          : (_isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    // Safely extract pagination data
    Map<String, dynamic> pagination = {};
    try {
      if (_shiftsData is Map<String, dynamic>) {
        final paginationData = _shiftsData['pagination'];
        if (paginationData is Map<String, dynamic>) {
          pagination = paginationData;
        }
      }
    } catch (e) {
      // Use empty pagination if extraction fails
    }
    final totalItems = pagination['total'] ?? 0;
    final currentPageItems = _filteredDuties.length;
    
    // Count by status from current filtered data
    final activeCount = _filteredDuties.where((d) => d.status == ShiftStatus.IN_PROGRESS).length;
    final completedCount = _filteredDuties.where((d) => d.status == ShiftStatus.COMPLETED).length;
    final scheduledCount = _filteredDuties.where((d) => d.status == ShiftStatus.SCHEDULED).length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pagination info
          if (totalItems > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isDarkMode ? AppTheme.surfaceColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing $currentPageItems of $totalItems shifts',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  if (_totalPages > 1)
                    Text(
                      'Page $_currentPage of $_totalPages',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Scheduled',
                  scheduledCount.toString(),
                  Colors.orange,
                  Icons.schedule,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  activeCount.toString(),
                  AppTheme.successGreen,
                  Icons.play_circle_filled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  completedCount.toString(),
                  Colors.blue,
                  Icons.check_circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 48,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Duties Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty || _selectedFilter != 'All'
                  ? 'Try adjusting your search or filter criteria'
                  : 'No duties have been created yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutiesList() {
    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredDuties.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredDuties.length) {
            // Load more button
            return _buildLoadMoreButton();
          }
          
          final duty = _filteredDuties[index];
          return _buildDutyCard(duty);
        },
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: () {
            if (_isLoadingMore) return;
            _currentPage++;
            _loadData(loadMore: true);
          },
          icon: _isLoadingMore
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.expand_more),
          label: Text(_isLoadingMore ? 'Loading...' : 'Load More'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDutyCard(DutyAssignment duty) {
    // Try to get crew info from API data first, then fallback to local data
    final shiftData = _getShiftDataById(duty.backendShiftId ?? duty.id);
    
    // Use the crew info from the duty assignment model first, then fallback to API data
    final guard = duty.trainManager != null 
        ? {
            'name': duty.trainManager!.name,
            'employeeId': duty.trainManager!.employeeId,
            'id': duty.trainManager!.employeeId,
          }
        : _getCrewMemberInfo(duty.guardId, shiftData?['trainManager']);
        
    final pilot = duty.locoPilot != null 
        ? {
            'name': duty.locoPilot!.name,
            'employeeId': duty.locoPilot!.employeeId,
            'id': duty.locoPilot!.employeeId,
          }
        : _getCrewMemberInfo(duty.locoPilotId, shiftData?['locoPilot']);
    final assistant = duty.assistantId != null 
        ? _crewMembers.where((c) => c.id == duty.assistantId).firstOrNull 
        : null;
    
    final duration = duty.duration;
    final durationColor = AppTheme.getDurationColor(duration);
    final statusColor = AppTheme.getStatusColor(duty.status.displayName);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DutyDetailScreen(
              duty: duty,
              crewMembers: _crewMembers,
            ),
          ),
        ).then((result) {
          // Refresh data if duty was ended
          if (result == true) {
            _loadData();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentOrange,
                        AppTheme.accentOrange.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentOrange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.train_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Train ${duty.trainNumber}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              duty.section ?? '${duty.fromStation} → ${duty.toStation}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        duty.status.displayName,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            durationColor,
                            durationColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${duration.inHours}h ${duration.inMinutes % 60}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Crew Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDarkMode ? AppTheme.surfaceColor.withOpacity(0.5) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildCrewInfo(
                          'Train Manager',
                          guard?['name'] ?? 'Unknown',
                          guard?['employeeId'] ?? 'N/A',
                          Icons.security_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
                      ),
                      Expanded(
                        child: _buildCrewInfo(
                          'Loco Pilot',
                          pilot?['name'] ?? 'Unknown',
                          pilot?['employeeId'] ?? 'N/A',
                          Icons.person_rounded,
                        ),
                      ),
                    ],
                  ),
                  if (assistant != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
                    ),
                    const SizedBox(height: 12),
                    _buildCrewInfo(
                      'Assistant',
                      assistant?.name ?? 'Unknown',
                      assistant?.employeeId ?? 'N/A',
                      Icons.person_outline_rounded,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Time Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Started: ${_formatTime(duty.startTime)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (duty.endTime != null)
                  Row(
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ended: ${_formatTime(duty.endTime!)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            if (duty.notes != null && duty.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentOrange.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_rounded,
                      size: 16,
                      color: AppTheme.accentOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        duty.notes!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );

  }

  Widget _buildCrewInfo(String role, String name, String id, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppTheme.accentOrange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            role,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            id,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _getShiftDataById(String dutyId) {
    // Safely extract shifts data
    List<dynamic> shifts = [];
    try {
      if (_shiftsData is Map<String, dynamic>) {
        final shiftsData = _shiftsData['shifts'];
        if (shiftsData is List) {
          shifts = shiftsData;
        }
      } else if (_shiftsData is List) {
        shifts = _shiftsData as List;
      }
    } catch (e) {
      // Return null if extraction fails
    }
    try {
      final matchingShift = shifts.where((shift) => shift is Map<String, dynamic> && shift['id'] == dutyId).firstOrNull;
      return matchingShift as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? _getCrewMemberInfo(String? crewId, Map<String, dynamic>? apiCrewData) {
    // First try to get from API data
    if (apiCrewData != null) {
      return {
        'name': apiCrewData['name'] ?? 'Unknown',
        'employeeId': apiCrewData['employeeId'] ?? 'N/A',
        'id': apiCrewData['id'] ?? crewId,
      };
    }
    
    // Fallback to local crew data
    if (crewId != null) {
      final localCrew = _crewMembers.where((c) => c.id == crewId).firstOrNull;
      if (localCrew != null) {
        return {
          'name': localCrew.name,
          'employeeId': localCrew.employeeId,
          'id': localCrew.id,
        };
      }
    }
    
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}