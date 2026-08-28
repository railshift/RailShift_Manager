import 'package:flutter/material.dart';
import '../models/crew_member.dart';
import '../models/duty_assignment.dart';
import '../models/staff.dart';
import '../services/database_service.dart';
import '../services/shift_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'alert_management_screen.dart';
import '../widgets/duty_card.dart';
import '../utils/data_parser.dart';

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
      notes: 'Current duty hours: ${DataParser.safeDoubleValue(shiftData['currentDutyHours']).toStringAsFixed(1)}h',
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
        lobbySignOn: DataParser.safeBoolValue(shiftData['lobbySignOn']),
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
          return DutyCard(
            duty: duty,
            crewMembers: _crewMembers,
            isDarkMode: _isDarkMode,
            onRefresh: _loadData,
          );
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



  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}