import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/user_management_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final UserManagementService _userService = UserManagementService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isDarkMode = true;
  List<User> _users = [];
  List<User> _filteredUsers = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  Map<String, dynamic> _summary = {};
  UserRole? _roleFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isDarkMode = RailShiftManagerApp.isDarkMode.value;
    _checkPermissionAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndLoad() async {
    final currentUser = _authService.currentUser;
    if (currentUser?.role != UserRole.SUPERADMIN) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. SUPERADMIN permission required.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      print('👥 Loading user management data...');
      final summaryResponse = await _userService.getUserManagementSummary();
      final summaryData = summaryResponse['data'];

      final users = (summaryData['users'] as List)
          .map((u) => User.fromJson(u))
          .toList();

      setState(() {
        _users = users;
        _pendingRequests = List<Map<String, dynamic>>.from(
            summaryData['pendingRequests'] ?? []);
        _summary = summaryData['summary'] ?? {};
        _isLoading = false;
      });
      _applyFilters();
      print('✅ Loaded ${_users.length} users and ${_pendingRequests.length} pending requests');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((u) {
        final matchesSearch = query.isEmpty ||
            u.name.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query) ||
            u.employeeId.toLowerCase().contains(query) ||
            (u.division?.toLowerCase().contains(query) ?? false);
        final matchesRole = _roleFilter == null || u.role == _roleFilter;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = _isDarkMode ? AppTheme.primaryNavy : AppTheme.lightBackground;
    final card = _isDarkMode ? AppTheme.cardBackground : AppTheme.lightCardBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left, size: 28),
        ),
        title: const Text('User Management'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentOrange,
          labelColor: AppTheme.accentOrange,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: 'All Users (${_users.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllUsersTab(card),
                _buildPendingTab(card),
              ],
            ),
    );
  }

  // ── Stats header ──────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final stats = [
      ('Total', '${_summary['totalUsers'] ?? _users.length}', Icons.people_rounded, Colors.blue),
      ('Active', '${_summary['activeUsers'] ?? _users.where((u) => u.status == UserStatus.ACTIVE).length}', Icons.check_circle_rounded, AppTheme.successGreen),
      ('Inactive', '${_summary['inactiveUsers'] ?? _users.where((u) => u.status == UserStatus.INACTIVE).length}', Icons.pause_circle_rounded, AppTheme.warningOrange),
      ('Suspended', '${_summary['suspendedUsers'] ?? _users.where((u) => u.status == UserStatus.SUSPENDED).length}', Icons.block_rounded, AppTheme.errorRed),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = stats[i];
          return Container(
            width: 90,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (s.$4 as Color).withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.$3 as IconData, color: s.$4 as Color, size: 20),
                const SizedBox(height: 4),
                Text(s.$2, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: s.$4 as Color)),
                Text(s.$1, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Search + filter bar ───────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search name, email, ID…',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildRoleFilterChip(),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip() {
    return PopupMenuButton<UserRole?>(
      onSelected: (role) {
        setState(() => _roleFilter = role);
        _applyFilters();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('All Roles')),
        const PopupMenuItem(value: UserRole.SUPERADMIN, child: Text('SUPERADMIN')),
        const PopupMenuItem(value: UserRole.ADMIN, child: Text('ADMIN')),
        const PopupMenuItem(value: UserRole.USER, child: Text('USER')),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _roleFilter != null ? AppTheme.accentOrange.withOpacity(0.15) : (_isDarkMode ? AppTheme.cardBackground : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _roleFilter != null ? AppTheme.accentOrange : (_isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor)),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_list_rounded, size: 16, color: _roleFilter != null ? AppTheme.accentOrange : AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              _roleFilter?.toString().split('.').last ?? 'Role',
              style: TextStyle(fontSize: 12, color: _roleFilter != null ? AppTheme.accentOrange : AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── All Users tab ─────────────────────────────────────────────────────────
  Widget _buildAllUsersTab(Color card) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentOrange,
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildStatsRow(),
          _buildSearchBar(),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredUsers.isEmpty
                ? _buildEmptyState('No users found', Icons.people_outline)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (_, i) => _buildUserCard(_filteredUsers[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final statusColor = _statusColor(user.status);
    final roleColor = _roleColor(user.role);
    final initials = user.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return GestureDetector(
      onTap: () => _showUserDetail(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: roleColor.withOpacity(0.4), width: 1.5),
              ),
              child: Center(
                child: Text(initials, style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                      ),
                      _roleBadge(user.role),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(user.employeeId, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      if (user.division != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.corporate_fare_rounded, size: 11, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(user.division!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status dot
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(height: 4),
                Text(user.status.toString().split('.').last, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ── Pending tab ───────────────────────────────────────────────────────────
  Widget _buildPendingTab(Color card) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentOrange,
      child: _pendingRequests.isEmpty
          ? _buildEmptyState('No pending requests', Icons.check_circle_outline)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingRequests.length,
              itemBuilder: (_, i) => _buildPendingCard(_pendingRequests[i]),
            ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> req) {
    final name = req['name']?.toString() ?? 'Unknown';
    final initials = name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    final role = req['role']?.toString() ?? 'USER';
    final division = req['division']?.toString();
    final requestedAt = req['requestedAt']?.toString() ?? req['createdAt']?.toString();
    String dateStr = '';
    if (requestedAt != null) {
      try {
        final dt = DateTime.parse(requestedAt).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.warningOrange.withOpacity(0.4)),
                  ),
                  child: Center(child: Text(initials, style: const TextStyle(color: AppTheme.warningOrange, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(req['email']?.toString() ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roleColor(_roleFromString(role)).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(role, style: TextStyle(color: _roleColor(_roleFromString(role)), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (division != null) ...[
                  Icon(Icons.corporate_fare_rounded, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(division, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 12),
                ],
                if (dateStr.isNotEmpty) ...[
                  Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('Requested $dateStr', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectUser(req['id']?.toString() ?? ''),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: BorderSide(color: AppTheme.errorRed.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveUser(req['id']?.toString() ?? ''),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ── User detail bottom sheet ──────────────────────────────────────────────
  void _showUserDetail(User user) {
    final statusColor = _statusColor(user.status);
    final roleColor = _roleColor(user.role);
    final initials = user.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? AppTheme.cardBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: roleColor.withOpacity(0.5), width: 2),
                          ),
                          child: Center(child: Text(initials, style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 20))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 2),
                              Text(user.designation ?? user.role.toString().split('.').last,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              const SizedBox(height: 6),
                              Row(children: [_roleBadge(user.role), const SizedBox(width: 6), _statusBadge(user.status)]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Details grid
                    _detailRow(Icons.badge_outlined, 'Employee ID', user.employeeId),
                    _detailRow(Icons.email_outlined, 'Email', user.email),
                    if (user.phone != null) _detailRow(Icons.phone_outlined, 'Phone', user.phone!),
                    if (user.division != null) _detailRow(Icons.corporate_fare_rounded, 'Division', user.division!),
                    _detailRow(Icons.calendar_today_rounded, 'Joined', _formatDate(user.createdAt)),
                    if (user.lastLogin != null) _detailRow(Icons.login_rounded, 'Last Login', _formatDate(user.lastLogin!)),
                    _detailRow(Icons.verified_rounded, 'Verified', user.isVerified ? 'Yes' : 'No'),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Actions
                    Text('Actions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary)),
                    const SizedBox(height: 12),
                    _buildActionButtons(user),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.accentOrange),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildActionButtons(User user) {
    final isSelf = _authService.currentUser?.id == user.id;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (user.status == UserStatus.INACTIVE && !isSelf)
          _actionChip('Activate', Icons.check_circle_outline, AppTheme.successGreen, () => _activateUser(user.id)),
        if (user.status == UserStatus.ACTIVE && !isSelf)
          _actionChip('Deactivate', Icons.pause_circle_outline, AppTheme.warningOrange, () => _deactivateUser(user.id)),
        if (!isSelf)
          _actionChip('Change Role', Icons.manage_accounts_rounded, Colors.blue, () => _showChangeRoleDialog(user)),
        if (!isSelf)
          _actionChip('Delete', Icons.delete_outline_rounded, AppTheme.errorRed, () => _confirmDelete(user)),
      ],
    );
  }

  Widget _actionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }


  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showChangeRoleDialog(User user) {
    UserRole selected = user.role;
    Navigator.pop(context); // close bottom sheet
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Role — ${user.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.map((role) => RadioListTile<UserRole>(
              value: role,
              groupValue: selected,
              onChanged: (v) => setS(() => selected = v!),
              title: Text(role.toString().split('.').last),
              activeColor: AppTheme.accentOrange,
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _changeRole(user.id, selected);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(User user) {
    Navigator.pop(context); // close bottom sheet
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _isDarkMode ? AppTheme.cardBackground : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User'),
        content: Text('Are you sure you want to permanently delete ${user.name}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUser(user.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── API actions ───────────────────────────────────────────────────────────
  Future<void> _approveUser(String id) async {
    try {
      await _userService.approveUser(id);
      _showSnack('User approved', AppTheme.successGreen);
      await _loadData();
    } catch (e) {
      _showSnack('Error: $e', AppTheme.errorRed);
    }
  }

  Future<void> _rejectUser(String id) async {
    try {
      await _userService.rejectUser(id, reason: 'Rejected by admin');
      _showSnack('User rejected', AppTheme.warningOrange);
      await _loadData();
    } catch (e) {
      _showSnack('Error: $e', AppTheme.errorRed);
    }
  }

  Future<void> _activateUser(String id) async {
    Navigator.pop(context);
    try {
      await _userService.activateUser(id);
      _showSnack('User activated', AppTheme.successGreen);
      await _loadData();
    } catch (e) {
      _showSnack('Error: $e', AppTheme.errorRed);
    }
  }

  Future<void> _deactivateUser(String id) async {
    Navigator.pop(context);
    try {
      await _userService.deactivateUser(id);
      _showSnack('User deactivated', AppTheme.warningOrange);
      await _loadData();
    } catch (e) {
      _showSnack('Error: $e', AppTheme.errorRed);
    }
  }

  Future<void> _changeRole(String id, UserRole role) async {
    try {
      await _userService.changeUserRole(id, role);
      _showSnack('Role updated', AppTheme.successGreen);
      await _loadData();
    } catch (e) {
      _showSnack('Error: $e', AppTheme.errorRed);
    }
  }

  Future<void> _deleteUser(String id) async {
    try {
      await _userService.deleteUser(id);
      _showSnack('User deleted', AppTheme.errorRed);
      await _loadData();
    } catch (e) {
      _showSnack('Error: $e', AppTheme.errorRed);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Color _statusColor(UserStatus s) {
    switch (s) {
      case UserStatus.ACTIVE: return AppTheme.successGreen;
      case UserStatus.INACTIVE: return AppTheme.warningOrange;
      case UserStatus.SUSPENDED: return AppTheme.errorRed;
    }
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.SUPERADMIN: return Colors.purple;
      case UserRole.ADMIN: return Colors.blue;
      case UserRole.USER: return AppTheme.textSecondary;
    }
  }

  UserRole _roleFromString(String s) {
    switch (s.toUpperCase()) {
      case 'SUPERADMIN': return UserRole.SUPERADMIN;
      case 'ADMIN': return UserRole.ADMIN;
      default: return UserRole.USER;
    }
  }

  Widget _roleBadge(UserRole role) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(role.toString().split('.').last, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusBadge(UserStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status.toString().split('.').last, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppTheme.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
