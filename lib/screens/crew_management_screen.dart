import 'package:flutter/material.dart';
import '../models/crew_member.dart';
import '../services/database_service.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class CrewManagementScreen extends StatefulWidget {
  const CrewManagementScreen({super.key});

  @override
  State<CrewManagementScreen> createState() => _CrewManagementScreenState();
}

class _CrewManagementScreenState extends State<CrewManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  final DashboardService _dashboardService = DashboardService();
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, dynamic>? _staffStats;
  List<CrewMember> _allCrewMembers = [];
  List<CrewMember> _filteredCrewMembers = [];
  bool _isLoading = true;
  bool _isDarkMode = true;
  String _selectedStatusFilter = 'All';
  String _selectedRoleFilter = 'All';
  
  final List<String> _statusFilterOptions = ['All', 'Available', 'On Duty', 'Off Duty'];
  final List<String> _roleFilterOptions = ['All', 'Guards', 'Pilots', 'Assistants'];

  @override
  void initState() {
    super.initState();
    _isDarkMode = RailShiftManagerApp.isDarkMode.value;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final crewMembers = await _dbService.getCrewMembers();
      Map<String, dynamic>? staffStats;
      try {
        final statsResponse = await _dashboardService.getDashboardStats();
        staffStats = statsResponse['data']?['staff'];
      } catch (e) {
        print('Warning: Failed to load staff stats: $e');
      }
      
      setState(() {
        _allCrewMembers = crewMembers;
        _filteredCrewMembers = crewMembers;
        _staffStats = staffStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading crew data: $e')),
        );
      }
    }
  }

  void _filterCrewMembers() {
    setState(() {
      _filteredCrewMembers = _allCrewMembers.where((crew) {
        final matchesSearch = crew.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                             crew.employeeId.toLowerCase().contains(_searchController.text.toLowerCase());
        
        final matchesStatusFilter = _selectedStatusFilter == 'All' || 
                                   (_selectedStatusFilter == 'Available' && crew.status == CrewStatus.available) ||
                                   (_selectedStatusFilter == 'On Duty' && crew.status == CrewStatus.onDuty) ||
                                   (_selectedStatusFilter == 'Off Duty' && crew.status == CrewStatus.offDuty);
        
        final matchesRoleFilter = _selectedRoleFilter == 'All' ||
                                 (_selectedRoleFilter == 'Guards' && crew.role == CrewRole.guard) ||
                                 (_selectedRoleFilter == 'Pilots' && crew.role == CrewRole.locoPilot) ||
                                 (_selectedRoleFilter == 'Assistants' && crew.role == CrewRole.assistant);
        
        return matchesSearch && matchesStatusFilter && matchesRoleFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        title: const Text('Crew Management'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _showAddCrewDialog,
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndFilter(),
                _buildStatsHeader(),
                Expanded(
                  child: _buildCrewList(_filteredCrewMembers),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isDarkMode ? AppTheme.borderColor : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => _filterCrewMembers(),
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Search crew members...',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.search_rounded,
                            color: AppTheme.accentOrange,
                            size: 20,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        hintStyle: TextStyle(
                          color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showFilterDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Filter',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedStatusFilter != 'All' || _selectedRoleFilter != 'All') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentOrange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_alt_rounded,
                      color: AppTheme.accentOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Filters: ${_getActiveFiltersText()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearFilters,
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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
    );
  }

  Widget _buildStatsHeader() {
    // If we have API stats, use them. Otherwise fallback to calculating from the local list.
    final totalCount = _staffStats != null ? (_staffStats!['total'] ?? 0) : _allCrewMembers.length;
    final availableCount = _staffStats != null ? (_staffStats!['available'] ?? 0) : _allCrewMembers.where((c) => c.status == CrewStatus.available).length;
    final onDutyCount = _staffStats != null ? (_staffStats!['onDuty'] ?? 0) : _allCrewMembers.where((c) => c.status == CrewStatus.onDuty).length;
    final unavailableCount = _staffStats != null ? (_staffStats!['unavailable'] ?? 0) : _allCrewMembers.where((c) => c.status == CrewStatus.offDuty).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildEnhancedStatCard(
              'Total',
              '$totalCount',
              Icons.people_rounded,
              AppTheme.accentOrange,
              totalCount > 0 ? (totalCount / 50.0) : 0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildEnhancedStatCard(
              'Available',
              '$availableCount',
              Icons.check_circle_rounded,
              AppTheme.successGreen,
              totalCount > 0 ? (availableCount / totalCount.toDouble()) : 0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildEnhancedStatCard(
              'On Duty',
              '$onDutyCount',
              Icons.work_rounded,
              AppTheme.warningOrange,
              totalCount > 0 ? (onDutyCount / totalCount.toDouble()) : 0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildEnhancedStatCard(
              'Off Duty',
              '$unavailableCount',
              Icons.pause_circle_rounded,
              Colors.grey,
              totalCount > 0 ? (unavailableCount / totalCount.toDouble()) : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatCard(String label, String value, IconData icon, Color color, double progress) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.1) : Colors.grey.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isDarkMode ? AppTheme.borderColor : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: clampedProgress,
                  strokeWidth: 3,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCrewList(List<CrewMember> crewMembers) {

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: crewMembers.length,
      itemBuilder: (context, index) {
        final crew = crewMembers[index];
        return _buildCrewCard(crew);
      },
    );
  }

  Widget _buildCrewCard(CrewMember crew) {
    final statusColor = crew.status == CrewStatus.available 
        ? AppTheme.successGreen
        : crew.status == CrewStatus.onDuty 
            ? AppTheme.warningOrange 
            : AppTheme.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.1) : Colors.grey.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isDarkMode ? AppTheme.borderColor : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.accentOrange.withOpacity(0.1),
                  child: Text(
                    crew.name.split(' ').map((n) => n[0]).take(2).join().toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.accentOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isDarkMode ? AppTheme.cardBackground : Colors.white, 
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      crew.status == CrewStatus.available 
                          ? Icons.check
                          : crew.status == CrewStatus.onDuty 
                              ? Icons.work
                              : Icons.pause,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crew.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 16,
                        color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        crew.employeeId,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getRoleColor(crew.role),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getRoleIcon(crew.role),
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              crew.role.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          crew.status.displayName,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Edit ${crew.name} coming soon')),
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.accentOrange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(CrewRole role) {
    switch (role) {
      case CrewRole.guard:
        return Colors.blue;
      case CrewRole.locoPilot:
        return Colors.green;
      case CrewRole.assistant:
        return Colors.purple;
    }
  }

  IconData _getRoleIcon(CrewRole role) {
    switch (role) {
      case CrewRole.guard:
        return Icons.security_rounded;
      case CrewRole.locoPilot:
        return Icons.train_rounded;
      case CrewRole.assistant:
        return Icons.person_rounded;
    }
  }

  String _getActiveFiltersText() {
    List<String> filters = [];
    if (_selectedStatusFilter != 'All') {
      filters.add(_selectedStatusFilter);
    }
    if (_selectedRoleFilter != 'All') {
      filters.add(_selectedRoleFilter);
    }
    return filters.join(', ');
  }

  void _clearFilters() {
    setState(() {
      _selectedStatusFilter = 'All';
      _selectedRoleFilter = 'All';
    });
    _filterCrewMembers();
  }

  void _showAddCrewDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController employeeIdController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    
    CrewRole selectedRole = CrewRole.guard;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppTheme.accentOrange,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add New Crew Member',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter crew member details',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Form Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Personal Information Section
                              _buildSectionTitle('Personal Information', Icons.person_outline),
                              const SizedBox(height: 16),
                              
                              _buildDialogTextField(
                                controller: nameController,
                                label: 'Full Name',
                                hint: 'Enter full name',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter full name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              _buildDialogTextField(
                                controller: employeeIdController,
                                label: 'Employee ID',
                                hint: 'Enter employee ID',
                                icon: Icons.badge_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter employee ID';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              
                              // Contact Information Section
                              _buildSectionTitle('Contact Information', Icons.contact_phone_outlined),
                              const SizedBox(height: 16),
                              
                              _buildDialogTextField(
                                controller: phoneController,
                                label: 'Phone Number',
                                hint: 'Enter phone number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              _buildDialogTextField(
                                controller: emailController,
                                label: 'Email (Optional)',
                                hint: 'Enter email address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 24),
                              
                              // Role Section
                              _buildSectionTitle('Role', Icons.work_outline),
                              const SizedBox(height: 16),
                              
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Role',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isDarkMode ? AppTheme.borderColor : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: DropdownButtonFormField<CrewRole>(
                                      value: selectedRole,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      dropdownColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
                                      items: CrewRole.values.map((role) {
                                        return DropdownMenuItem<CrewRole>(
                                          value: role,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getRoleIcon(role),
                                                color: _getRoleColor(role),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(role.displayName),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          selectedRole = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.successGreen.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: AppTheme.successGreen,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'New crew members will be set as "Available" by default',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppTheme.successGreen,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _isDarkMode 
                          ? AppTheme.surfaceColor.withOpacity(0.5) 
                          : Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(
                                  color: _isDarkMode 
                                    ? AppTheme.textSecondary 
                                    : AppTheme.lightTextSecondary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: _isDarkMode 
                                    ? AppTheme.textSecondary 
                                    : AppTheme.lightTextSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  _addCrewMember(
                                    name: nameController.text,
                                    employeeId: employeeIdController.text,
                                    phone: phoneController.text,
                                    email: emailController.text,
                                    role: selectedRole,
                                  );
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentOrange,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Add Crew Member',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempStatusFilter = _selectedStatusFilter;
        String tempRoleFilter = _selectedRoleFilter;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: _isDarkMode ? AppTheme.cardBackground : AppTheme.lightCardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filter Crew Members',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Customize your crew view',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Filter Section
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.work_outline_rounded,
                                    color: AppTheme.successGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Filter by Status',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _statusFilterOptions.map((filter) {
                                final isSelected = tempStatusFilter == filter;
                                return FilterChip(
                                  label: Text(filter),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setDialogState(() {
                                      tempStatusFilter = filter;
                                    });
                                  },
                                  backgroundColor: _isDarkMode ? AppTheme.surfaceColor : Colors.grey.shade200,
                                  selectedColor: AppTheme.successGreen.withOpacity(0.2),
                                  checkmarkColor: AppTheme.successGreen,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppTheme.successGreen : (_isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Role Filter Section
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.people_outline_rounded,
                                    color: AppTheme.accentOrange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Filter by Role',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _roleFilterOptions.map((filter) {
                                final isSelected = tempRoleFilter == filter;
                                return FilterChip(
                                  label: Text(filter),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setDialogState(() {
                                      tempRoleFilter = filter;
                                    });
                                  },
                                  backgroundColor: _isDarkMode ? AppTheme.surfaceColor : Colors.grey.shade200,
                                  selectedColor: AppTheme.accentOrange.withOpacity(0.2),
                                  checkmarkColor: AppTheme.accentOrange,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppTheme.accentOrange : (_isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _isDarkMode 
                          ? AppTheme.surfaceColor.withOpacity(0.5) 
                          : Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setDialogState(() {
                                  tempStatusFilter = 'All';
                                  tempRoleFilter = 'All';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(
                                  color: _isDarkMode 
                                    ? AppTheme.textSecondary 
                                    : AppTheme.lightTextSecondary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Clear All',
                                style: TextStyle(
                                  color: _isDarkMode 
                                    ? AppTheme.textSecondary 
                                    : AppTheme.lightTextSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatusFilter = tempStatusFilter;
                                  _selectedRoleFilter = tempRoleFilter;
                                });
                                _filterCrewMembers();
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentOrange,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Apply Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: AppTheme.accentOrange,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDarkMode ? AppTheme.borderColor : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.accentOrange,
                  size: 18,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintStyle: TextStyle(
                color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  void _addCrewMember({
    required String name,
    required String employeeId,
    required String phone,
    required String email,
    required CrewRole role,
  }) {
    // TODO: Implement actual crew member addition to database
    // For now, just show success message
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
                'Crew member "$name" added successfully',
                style: const TextStyle(fontWeight: FontWeight.w500),
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

    // Reload data to show the new crew member
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}