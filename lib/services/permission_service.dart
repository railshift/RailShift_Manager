import '../models/user.dart';
import 'auth_service.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final AuthService _authService = AuthService();

  // ========== SHIFT MANAGEMENT PERMISSIONS ==========

  /// Check if current user can create shifts
  /// Permission: ADMIN, SUPERADMIN
  bool canCreateDuty() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can update shifts
  /// Permission: ADMIN, SUPERADMIN
  bool canEditDuty() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can complete shifts
  /// Permission: ADMIN, SUPERADMIN
  bool canCompleteShift() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can delete shifts
  /// Permission: SUPERADMIN only
  bool canDeleteDuty() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can submit alert responses
  /// Permission: ADMIN, SUPERADMIN
  bool canSubmitAlertResponse() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  // ========== USER MANAGEMENT PERMISSIONS ==========

  /// Check if current user can access user management
  /// Permission: SUPERADMIN only
  bool canManageUsers() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can approve/reject user registrations
  /// Permission: SUPERADMIN only
  bool canApproveUsers() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can change user roles
  /// Permission: SUPERADMIN only
  bool canChangeUserRoles() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can activate/deactivate users
  /// Permission: SUPERADMIN only
  bool canActivateDeactivateUsers() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can delete users
  /// Permission: SUPERADMIN only
  bool canDeleteUsers() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  // ========== DASHBOARD & VIEWING PERMISSIONS ==========

  /// Check if current user can view dashboard stats
  /// Permission: All authenticated users
  bool canViewDashboard() {
    final user = _authService.currentUser;
    return user != null;
  }

  /// Check if current user can view shift trends
  /// Permission: All authenticated users
  bool canViewShiftTrends() {
    final user = _authService.currentUser;
    return user != null;
  }

  /// Check if current user can view recent activities
  /// Permission: All authenticated users
  bool canViewRecentActivities() {
    final user = _authService.currentUser;
    return user != null;
  }

  /// Check if current user can view alerts summary
  /// Permission: All authenticated users
  bool canViewAlertsSummary() {
    final user = _authService.currentUser;
    return user != null;
  }

  // ========== CREW MANAGEMENT PERMISSIONS ==========

  /// Check if current user can manage crew members
  /// Permission: ADMIN, SUPERADMIN
  bool canManageCrew() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can add crew members
  /// Permission: ADMIN, SUPERADMIN
  bool canAddCrewMembers() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can edit crew members
  /// Permission: ADMIN, SUPERADMIN
  bool canEditCrewMembers() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can delete crew members
  /// Permission: SUPERADMIN only
  bool canDeleteCrewMembers() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  // ========== REPORTS & ANALYTICS PERMISSIONS ==========

  /// Check if current user can view reports
  /// Permission: All authenticated users
  bool canViewReports() {
    final user = _authService.currentUser;
    return user != null;
  }

  /// Check if current user can export reports
  /// Permission: ADMIN, SUPERADMIN
  bool canExportReports() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can view detailed analytics
  /// Permission: ADMIN, SUPERADMIN
  bool canViewDetailedAnalytics() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  // ========== DUTY VIEWING PERMISSIONS ==========

  /// Check if current user can view duty details
  /// Permission: All authenticated users
  bool canViewDutyDetails() {
    final user = _authService.currentUser;
    return user != null;
  }

  /// Check if current user can view all duties
  /// Permission: All authenticated users
  bool canViewAllDuties() {
    final user = _authService.currentUser;
    return user != null;
  }

  /// Check if current user can perform duty actions (start, end, etc.)
  /// Permission: ADMIN, SUPERADMIN
  bool canPerformDutyActions() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  // ========== SYSTEM ADMINISTRATION PERMISSIONS ==========

  /// Check if current user can access system settings
  /// Permission: SUPERADMIN only
  bool canAccessSystemSettings() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can view system logs
  /// Permission: SUPERADMIN only
  bool canViewSystemLogs() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user can manage system configuration
  /// Permission: SUPERADMIN only
  bool canManageSystemConfig() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  // ========== HELPER METHODS ==========

  /// Get user role display name
  String getUserRoleDisplayName() {
    final user = _authService.currentUser;
    if (user == null) return 'Guest';
    
    switch (user.role) {
      case UserRole.USER:
        return 'User';
      case UserRole.ADMIN:
        return 'Administrator';
      case UserRole.SUPERADMIN:
        return 'Super Administrator';
    }
  }

  /// Check if current user is admin or higher
  bool isAdminOrHigher() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.ADMIN || user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user is SUPERADMIN
  bool isSuperAdmin() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.SUPERADMIN;
  }

  /// Check if current user is regular user (read-only access)
  bool isRegularUser() {
    final user = _authService.currentUser;
    if (user == null) return false;
    
    return user.role == UserRole.USER;
  }

  /// Get current user role
  UserRole? getCurrentUserRole() {
    final user = _authService.currentUser;
    return user?.role;
  }

  /// Get permission summary for current user
  Map<String, bool> getPermissionSummary() {
    return {
      // Shift Management
      'canCreateDuty': canCreateDuty(),
      'canEditDuty': canEditDuty(),
      'canCompleteShift': canCompleteShift(),
      'canDeleteDuty': canDeleteDuty(),
      'canSubmitAlertResponse': canSubmitAlertResponse(),
      
      // User Management
      'canManageUsers': canManageUsers(),
      'canApproveUsers': canApproveUsers(),
      'canChangeUserRoles': canChangeUserRoles(),
      'canActivateDeactivateUsers': canActivateDeactivateUsers(),
      'canDeleteUsers': canDeleteUsers(),
      
      // Dashboard & Viewing
      'canViewDashboard': canViewDashboard(),
      'canViewShiftTrends': canViewShiftTrends(),
      'canViewRecentActivities': canViewRecentActivities(),
      'canViewAlertsSummary': canViewAlertsSummary(),
      
      // Crew Management
      'canManageCrew': canManageCrew(),
      'canAddCrewMembers': canAddCrewMembers(),
      'canEditCrewMembers': canEditCrewMembers(),
      'canDeleteCrewMembers': canDeleteCrewMembers(),
      
      // Reports & Analytics
      'canViewReports': canViewReports(),
      'canExportReports': canExportReports(),
      'canViewDetailedAnalytics': canViewDetailedAnalytics(),
      
      // Duty Viewing
      'canViewDutyDetails': canViewDutyDetails(),
      'canViewAllDuties': canViewAllDuties(),
      'canPerformDutyActions': canPerformDutyActions(),
      
      // System Administration
      'canAccessSystemSettings': canAccessSystemSettings(),
      'canViewSystemLogs': canViewSystemLogs(),
      'canManageSystemConfig': canManageSystemConfig(),
    };
  }

  /// Get user capabilities description
  String getUserCapabilitiesDescription() {
    final user = _authService.currentUser;
    if (user == null) return 'No access - please login';
    
    switch (user.role) {
      case UserRole.USER:
        return 'Read-only access to view duties, reports, and dashboard';
      case UserRole.ADMIN:
        return 'Can manage shifts, crew, submit alert responses, and view all data';
      case UserRole.SUPERADMIN:
        return 'Full system access including user management and system administration';
    }
  }
}