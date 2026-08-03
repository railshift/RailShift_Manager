import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'auth_service.dart';

class UserManagementService {
  static const String _baseUrl = 'https://api.dutyhours.in/api/v1';
  final AuthService _authService = AuthService();

  // Singleton pattern
  static final UserManagementService _instance = UserManagementService._internal();
  factory UserManagementService() => _instance;
  UserManagementService._internal();

  /// Get all users with optional filtering
  /// GET /api/v1/users
  /// Permission: SUPERADMIN only
  Future<Map<String, dynamic>> getAllUsers({
    UserStatus? status,
    UserRole? role,
    String? division,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) {
        queryParams['status'] = status.toString().split('.').last;
      }
      if (role != null) {
        queryParams['role'] = role.toString().split('.').last;
      }
      if (division != null && division.isNotEmpty) {
        queryParams['division'] = division;
      }

      final uri = Uri.parse('$_baseUrl/users').replace(queryParameters: queryParams);
      
      print('👥 Fetching users from: $uri');
      
      final response = await http.get(
        uri,
        headers: _authService.getAuthHeaders(),
      );

      print('👥 Users response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get users');
      }
    } catch (e) {
      print('❌ Error fetching users: $e');
      rethrow;
    }
  }

  /// Get pending user registration requests
  /// GET /api/v1/users/pending-requests
  /// Permission: SUPERADMIN only
  Future<Map<String, dynamic>> getPendingUserRequests() async {
    try {
      final url = Uri.parse('$_baseUrl/users/pending-requests');
      
      print('⏳ Fetching pending user requests from: $url');
      
      final response = await http.get(
        url,
        headers: _authService.getAuthHeaders(),
      );

      print('⏳ Pending requests response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get pending requests');
      }
    } catch (e) {
      print('❌ Error fetching pending requests: $e');
      rethrow;
    }
  }

  /// Get user by ID
  /// GET /api/v1/users/:id
  /// Permission: SUPERADMIN only
  Future<User> getUserById(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId');
      
      print('👤 Fetching user by ID from: $url');
      
      final response = await http.get(
        url,
        headers: _authService.getAuthHeaders(),
      );

      print('👤 User by ID response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 404) {
        throw Exception('User not found.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        return User.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get user');
      }
    } catch (e) {
      print('❌ Error fetching user by ID: $e');
      rethrow;
    }
  }

  /// Approve a pending user registration
  /// POST /api/v1/users/:id/approve
  /// Permission: SUPERADMIN only
  Future<User> approveUser(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId/approve');
      
      print('✅ Approving user: $userId');
      
      final response = await http.post(
        url,
        headers: _authService.getAuthHeaders(),
        body: json.encode({}), // Empty body as per API docs
      );

      print('✅ Approve user response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 404) {
        throw Exception('User not found.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        print('✅ User approved successfully: ${responseData['data']['name']}');
        return User.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to approve user');
      }
    } catch (e) {
      print('❌ Error approving user: $e');
      rethrow;
    }
  }

  /// Reject a pending user registration
  /// POST /api/v1/users/:id/reject
  /// Permission: SUPERADMIN only
  Future<Map<String, dynamic>> rejectUser(String userId, {String? reason}) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId/reject');
      
      print('❌ Rejecting user: $userId with reason: ${reason ?? 'No reason provided'}');
      
      final requestBody = <String, dynamic>{};
      if (reason != null && reason.isNotEmpty) {
        requestBody['reason'] = reason;
      }
      
      final response = await http.post(
        url,
        headers: _authService.getAuthHeaders(),
        body: json.encode(requestBody),
      );

      print('❌ Reject user response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 404) {
        throw Exception('User not found.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        print('❌ User rejected successfully');
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to reject user');
      }
    } catch (e) {
      print('❌ Error rejecting user: $e');
      rethrow;
    }
  }

  /// Change user role
  /// PATCH /api/v1/users/:id/role
  /// Permission: SUPERADMIN only
  Future<User> changeUserRole(String userId, UserRole newRole) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId/role');
      
      print('🔄 Changing user role: $userId to ${newRole.toString().split('.').last}');
      
      final requestBody = {
        'role': newRole.toString().split('.').last,
      };
      
      final response = await http.patch(
        url,
        headers: _authService.getAuthHeaders(),
        body: json.encode(requestBody),
      );

      print('🔄 Change role response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 404) {
        throw Exception('User not found.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        print('🔄 User role changed successfully');
        return User.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to change user role');
      }
    } catch (e) {
      print('❌ Error changing user role: $e');
      rethrow;
    }
  }

  /// Update user details
  /// PATCH /api/v1/users/:id
  /// Permission: SUPERADMIN only
  Future<User> updateUser(String userId, {
    String? name,
    String? email,
    String? phone,
    String? division,
    String? designation,
    String? password,
    int? priority,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId');
      
      print('📝 Updating user: $userId');
      
      final requestBody = <String, dynamic>{};
      if (name != null) requestBody['name'] = name;
      if (email != null) requestBody['email'] = email;
      if (phone != null) requestBody['phone'] = phone;
      if (division != null) requestBody['division'] = division;
      if (designation != null) requestBody['designation'] = designation;
      if (password != null) requestBody['password'] = password;
      if (priority != null) requestBody['priority'] = priority;
      
      if (requestBody.isEmpty) {
        throw Exception('No fields to update');
      }
      
      print('📝 Update payload: ${json.encode(requestBody)}');
      
      final response = await http.patch(
        url,
        headers: _authService.getAuthHeaders(),
        body: json.encode(requestBody),
      );

      print('📝 Update user response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 404) {
        throw Exception('User not found.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        print('📝 User updated successfully');
        return User.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update user');
      }
    } catch (e) {
      print('❌ Error updating user: $e');
      rethrow;
    }
  }

  /// Activate a deactivated user
  /// POST /api/v1/users/:id/activate
  /// Permission: SUPERADMIN only
  Future<User> activateUser(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId/activate');
      
      print('🟢 Activating user: $userId');
      
      final response = await http.post(
        url,
        headers: _authService.getAuthHeaders(),
        body: json.encode({}), // Empty body
      );

      print('🟢 Activate user response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 404) {
        throw Exception('User not found.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        print('🟢 User activated successfully');
        return User.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to activate user');
      }
    } catch (e) {
      print('❌ Error activating user: $e');
      rethrow;
    }
  }

  /// Deactivate an active user
  /// POST /api/v1/users/:id/deactivate
  /// Permission: SUPERADMIN only
  Future<User> deactivateUser(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId/deactivate');
      
      print('🔴 Deactivating user: $userId');
      
      final response = await http.post(
        url,
        headers: _authService.getAuthHeaders(),
        body: json.encode({}), // Empty body
      );

      print('🔴 Deactivate user response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 404) {
        throw Exception('User not found.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        print('🔴 User deactivated successfully');
        return User.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to deactivate user');
      }
    } catch (e) {
      print('❌ Error deactivating user: $e');
      rethrow;
    }
  }

  /// Permanently delete a user account
  /// DELETE /api/v1/users/:id
  /// Permission: SUPERADMIN only
  Future<void> deleteUser(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId');
      
      print('🗑️ Deleting user: $userId');
      
      final response = await http.delete(
        url,
        headers: _authService.getAuthHeaders(),
      );

      print('🗑️ Delete user response status: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 401) {
        await _authService.handleTokenExpiration();
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 403) {
        throw Exception('Access denied. SUPERADMIN permission required.');
      }

      if (response.statusCode == 404) {
        throw Exception('User not found.');
      }

      if (response.statusCode == 200 && responseData['success']) {
        print('🗑️ User deleted successfully');
      } else {
        throw Exception(responseData['message'] ?? 'Failed to delete user');
      }
    } catch (e) {
      print('❌ Error deleting user: $e');
      rethrow;
    }
  }

  /// Get comprehensive user management data
  /// Combines multiple endpoints for dashboard view
  Future<Map<String, dynamic>> getUserManagementSummary() async {
    try {
      print('📊 Fetching user management summary...');
      
      // Make parallel requests for efficiency
      final futures = await Future.wait([
        getAllUsers(limit: 50), // Get all users
        getPendingUserRequests(), // Get pending requests
      ]);

      final allUsersResponse = futures[0];
      final pendingRequestsResponse = futures[1];

      final allUsers = allUsersResponse['data']['users'] as List? ?? [];
      final pendingRequests = pendingRequestsResponse['data']['pendingRequests'] as List? ?? [];

      // Calculate summary statistics
      final totalUsers = allUsers.length;
      final activeUsers = allUsers.where((u) => u['status'] == 'ACTIVE').length;
      final inactiveUsers = allUsers.where((u) => u['status'] == 'INACTIVE').length;
      final suspendedUsers = allUsers.where((u) => u['status'] == 'SUSPENDED').length;
      
      final adminUsers = allUsers.where((u) => u['role'] == 'ADMIN').length;
      final regularUsers = allUsers.where((u) => u['role'] == 'USER').length;
      final superAdminUsers = allUsers.where((u) => u['role'] == 'SUPERADMIN').length;

      print('📊 User management summary calculated successfully');

      return {
        'success': true,
        'data': {
          'summary': {
            'totalUsers': totalUsers,
            'activeUsers': activeUsers,
            'inactiveUsers': inactiveUsers,
            'suspendedUsers': suspendedUsers,
            'pendingRequests': pendingRequests.length,
          },
          'roleDistribution': {
            'SUPERADMIN': superAdminUsers,
            'ADMIN': adminUsers,
            'USER': regularUsers,
          },
          'users': allUsers,
          'pendingRequests': pendingRequests,
          'lastUpdated': DateTime.now().toIso8601String(),
        }
      };
    } catch (e) {
      print('❌ Error fetching user management summary: $e');
      rethrow;
    }
  }
}

/// User management filter options
class UserManagementFilter {
  final UserStatus? status;
  final UserRole? role;
  final String? division;
  final String? searchQuery;

  UserManagementFilter({
    this.status,
    this.role,
    this.division,
    this.searchQuery,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    
    if (status != null) {
      params['status'] = status.toString().split('.').last;
    }
    if (role != null) {
      params['role'] = role.toString().split('.').last;
    }
    if (division != null && division!.isNotEmpty) {
      params['division'] = division!;
    }
    
    return params;
  }
}

/// User action result for UI feedback
class UserActionResult {
  final bool success;
  final String message;
  final User? user;
  final Map<String, dynamic>? data;

  UserActionResult({
    required this.success,
    required this.message,
    this.user,
    this.data,
  });

  factory UserActionResult.success(String message, {User? user, Map<String, dynamic>? data}) {
    return UserActionResult(
      success: true,
      message: message,
      user: user,
      data: data,
    );
  }

  factory UserActionResult.error(String message) {
    return UserActionResult(
      success: false,
      message: message,
    );
  }
}