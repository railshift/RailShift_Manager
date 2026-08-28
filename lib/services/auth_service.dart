import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'navigation_service.dart';
import 'notification_service.dart';

class AuthService {
  // Production Backend URL with API v1 prefix as per documentation
  static const String _baseUrl = 'https://api.dutyhours.in/api/v1';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  static const String _keepLoggedInKey = 'keep_logged_in';
  static const String _lastLoginKey = 'last_login_time';
  static const Duration _loginTimeout = Duration(seconds: 75);

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SharedPreferences? _prefs;
  User? _currentUser;
  AuthTokens? _tokens;

  String _tokenPreview(String token) {
    if (token.isEmpty) return '<empty>';
    final end = token.length < 20 ? token.length : 20;
    return '${token.substring(0, end)}...';
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    final accessToken = _prefs?.getString(_accessTokenKey);
    final refreshToken = _prefs?.getString(_refreshTokenKey);
    final userData = _prefs?.getString(_userKey);
    final keepLoggedIn = _prefs?.getBool(_keepLoggedInKey) ?? false;
    final lastLoginStr = _prefs?.getString(_lastLoginKey);

    if (accessToken != null && refreshToken != null && userData != null) {
      // Check if user should stay logged in
      if (keepLoggedIn && lastLoginStr != null) {
        final lastLogin = DateTime.parse(lastLoginStr);
        final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
        
        if (daysSinceLogin < 1) { // Keep logged in for 1 day
          _tokens = AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          _currentUser = User.fromJson(json.decode(userData));
          

          // Re-register FCM token on auto-login so the backend has the freshest token
          _registerFCMToken();
          return;
        } else {
          print('🔐 Auto-login expired after 1 day, clearing auth data');
          await _clearAuthData();
          return;
        }
      }
      
      _tokens = AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      _currentUser = User.fromJson(json.decode(userData));
    }
  }

  bool get isAuthenticated => _tokens != null && _currentUser != null;
  User? get currentUser => _currentUser;
  String? get accessToken => _tokens?.accessToken;

  Future<Map<String, dynamic>> register({
    required String employeeId,
    required String name,
    required String email,
    String? phone,
    String? division,
    String? designation,
    required String password,
    UserRole role = UserRole.USER,
  }) async {
    print('🚀 === REGISTRATION PROCESS STARTED ===');
    print('📝 Attempting registration for: $email');
    print('👤 Employee ID: $employeeId');
    print('🏷️ Name: $name');
    print('📧 Email: $email');
    print('📱 Phone: ${phone ?? 'Not provided'}');
    print('🏢 Division: ${division ?? 'Not provided'}');
    print('💼 Designation: ${designation ?? 'Not provided'}');
    print('🔐 Password: ${password.replaceAll(RegExp(r'.'), '*')} (${password.length} chars)');
    print('👔 Role: ${role.toString().split('.').last}');
    
    final url = Uri.parse('$_baseUrl/auth/register');
    print('🌐 API URL: $url');
    
    final requestBody = {
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'phone': phone,
      'division': division,
      'designation': designation,
      'password': password,
      'role': role.toString().split('.').last,
    };
    
    print('⏳ Sending request to server...');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(_loginTimeout);

      print('📥 Registration response status: ${response.statusCode}');
      print('📥 Registration response headers: ${response.headers}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 201 && responseData['success']) {
        final userData = responseData['data']['user'];
        
        print('✅ Registration successful for user: ${userData['name']}');
        print('🎉 User ID: ${userData['id']}');
        print('👔 User Role: ${userData['role']}');
        print('📊 User Status: ${userData['status']} (New accounts start as INACTIVE)');
        print('🏢 Division: ${userData['division'] ?? 'Not set'}');
        print('💼 Designation: ${userData['designation'] ?? 'Not set'}');
        
        // Registration returns user only (no tokens) — account is INACTIVE until approved
        _currentUser = User.fromJson(userData);
        
        print('🔐 === REGISTRATION PROCESS COMPLETED ===');
        
        return responseData;
      } else {
        print('❌ Registration failed with status: ${response.statusCode}');
        print('❌ Error message: ${responseData['message']}');
        if (responseData['errors'] != null) {
          print('❌ Validation errors: ${responseData['errors']}');
        }
        throw Exception(responseData['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print('💥 Registration error occurred: $e');
      print('🚨 Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {

    
    final url = Uri.parse('$_baseUrl/auth/login');

    
    final requestBody = {
      'email': email,
      'password': password,
    };
    

    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(_loginTimeout);



      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        final userData = responseData['data']['user'];
        // Support both token response shapes:
        // 1) data.accessToken/data.refreshToken (current backend)
        // 2) data.tokens.accessToken/data.tokens.refreshToken (older docs)
        final data = responseData['data'] as Map<String, dynamic>? ?? {};
        final tokensData = data['tokens'] as Map<String, dynamic>? ?? {};
        final accessToken =
            data['accessToken']?.toString() ?? tokensData['accessToken']?.toString() ?? '';
        final refreshToken =
            data['refreshToken']?.toString() ?? tokensData['refreshToken']?.toString() ?? '';

        if (accessToken.isEmpty || refreshToken.isEmpty) {
          throw Exception('Login succeeded but tokens are missing in response');
        }
        

        
        _currentUser = User.fromJson(userData);
        _tokens = AuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        

        await _saveAuthData(keepLoggedIn: true); // Keep user logged in for 1 day
        
        // Register FCM Token for push notifications
        await _registerFCMToken();
        
        // Save credentials for autofill
        await saveLoginCredentials(email, password);

        
        return responseData;
      } else {
        print('❌ Login failed with status: ${response.statusCode}');
        print('❌ Error message: ${responseData['message']}');
        throw Exception(responseData['message'] ?? 'Login failed');
      }
    } on TimeoutException catch (e) {
      print('💥 Login timed out after ${_loginTimeout.inSeconds}s: $e');
      print('🚨 Error type: ${e.runtimeType}');
      throw Exception('Login request timed out. Server may be waking up, please try again.');
    } on SocketException catch (e) {
      print('💥 Login network/socket error: $e');
      print('🚨 Error type: ${e.runtimeType}');
      throw Exception('Unable to connect to server. Check your internet connection and try again.');
    } on http.ClientException catch (e) {
      final message = e.message.toLowerCase();
      print('💥 Login HTTP client error: $e');
      print('🚨 Error type: ${e.runtimeType}');

      if (message.contains('failed host lookup') ||
          message.contains('socketexception') ||
          message.contains('connection')) {
        throw Exception('Server is unreachable right now. Check internet or try again shortly.');
      }

      throw Exception('Network error while logging in. Please try again.');
    } catch (e) {
      print('💥 Login error occurred: $e');
      print('🚨 Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> refreshToken() async {
    if (_tokens?.refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final url = Uri.parse('$_baseUrl/auth/refresh');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'refreshToken': _tokens!.refreshToken,
      }),
    );

    final responseData = json.decode(response.body);

    if (response.statusCode == 200 && responseData['success']) {
      final data = responseData['data'] as Map<String, dynamic>? ?? {};
      final tokensData = data['tokens'] as Map<String, dynamic>? ?? data;
      final accessToken = tokensData['accessToken']?.toString() ?? '';
      final refreshToken = tokensData['refreshToken']?.toString() ?? '';

      if (accessToken.isEmpty || refreshToken.isEmpty) {
        throw Exception('Token refresh succeeded but tokens are missing in response');
      }

      _tokens = AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _saveAuthData();
    } else {
      await logout();
      throw Exception('Token refresh failed');
    }
  }

  Future<User> getCurrentUser() async {
    if (_tokens?.accessToken == null) {
      throw Exception('No access token available');
    }

    final url = Uri.parse('$_baseUrl/auth/me');
    
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_tokens!.accessToken}',
      },
    );

    final responseData = json.decode(response.body);

    if (response.statusCode == 200 && responseData['success']) {
      _currentUser = User.fromJson(responseData['data']);
      await _saveAuthData();
      return _currentUser!;
    } else {
      throw Exception('Failed to get user data');
    }
  }

  Future<void> logout() async {
    try {
      if (_tokens?.accessToken != null) {
        // Unregister FCM token first
        await _unregisterFCMToken();

        final url = Uri.parse('$_baseUrl/auth/logout');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_tokens!.accessToken}',
          },
        );
      }
    } catch (e) {
      // Continue with logout even if API call fails
      print('Logout API call failed: $e');
    }

    _currentUser = null;
    _tokens = null;
    await _clearAuthData();
  }

  Future<void> _registerFCMToken() async {
    try {
      final token = await NotificationService().getFCMToken();
      if (token != null && _tokens?.accessToken != null) {
        final url = Uri.parse('$_baseUrl/fcm/register-token');
        

        final response = await http.post(
          url,
          headers: getAuthHeaders(),
          body: json.encode({'token': token}),
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {

        } else {
          print('⚠️ FCM token registration returned status ${response.statusCode}');
        }
      }
    } catch (e) {
      print('⚠️ Failed to register FCM token with backend: $e');
    }
  }

  Future<void> _unregisterFCMToken() async {
    try {
      if (_tokens?.accessToken != null) {
        final url = Uri.parse('$_baseUrl/fcm/unregister-token');
        print('🗑️ Unregistering FCM token from backend...');
        
        await http.delete(
          url,
          headers: getAuthHeaders(),
        );
      }
    } catch (e) {
      print('⚠️ Failed to unregister FCM token: $e');
    }
  }

  Future<void> _saveAuthData({bool keepLoggedIn = true}) async {
    if (_tokens != null && _currentUser != null) {
      await _prefs?.setString(_accessTokenKey, _tokens!.accessToken);
      await _prefs?.setString(_refreshTokenKey, _tokens!.refreshToken);
      await _prefs?.setString(_userKey, json.encode(_currentUser!.toJson()));
      await _prefs?.setBool(_keepLoggedInKey, keepLoggedIn);
      await _prefs?.setString(_lastLoginKey, DateTime.now().toIso8601String());
      
      if (keepLoggedIn) {

      }
    }
  }

  Future<void> _clearAuthData() async {
    await _prefs?.remove(_accessTokenKey);
    await _prefs?.remove(_refreshTokenKey);
    await _prefs?.remove(_userKey);
    await _prefs?.remove(_keepLoggedInKey);
    await _prefs?.remove(_lastLoginKey);
  }

  Map<String, String> getAuthHeaders() {
    if (_tokens?.accessToken == null) {
      throw Exception('No access token available');
    }
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_tokens!.accessToken}',
    };
  }

  // Check if token is expired and handle accordingly
  Future<bool> isTokenExpired() async {
    if (_tokens?.accessToken == null) return true;
    
    try {
      // Try to make a simple API call to check token validity
      final url = Uri.parse('$_baseUrl/auth/me');
      final response = await http.get(
        url,
        headers: getAuthHeaders(),
      );
      
      if (response.statusCode == 401) {
        print('🔑 Token expired, attempting refresh...');
        try {
          await refreshToken();
          return false; // Token refreshed successfully
        } catch (e) {
          print('❌ Token refresh failed: $e');
          return true; // Token refresh failed
        }
      }
      
      return response.statusCode != 200;
    } catch (e) {
      print('❌ Token validation error: $e');
      return true;
    }
  }

  // Force logout when token expires
  Future<void> handleTokenExpiration() async {
    print('🚨 Token expired - attempting final refresh before logout');
    
    // Try one more time to refresh the token before forcing logout
    try {
      await refreshToken();
      print('✅ Last-chance token refresh successful');
      return; // Don't logout if refresh succeeded
    } catch (e) {
      print('❌ Final token refresh failed: $e');
    }
    
    print('🚨 Forcing logout due to token expiration');
    await logout();
    NavigationService.showSessionExpiredDialog();
  }

  // Save login credentials for autofill (multiple credentials support)
  static const String _savedCredentialsKey = 'saved_credentials_list';
  
  Future<void> saveLoginCredentials(String email, String password) async {
    final credentials = await getSavedCredentialsList();
    
    // Remove existing credential with same email if exists
    credentials.removeWhere((cred) => cred['email'] == email);
    
    // Add new credential at the beginning
    credentials.insert(0, {
      'email': email,
      'password': password,
      'savedAt': DateTime.now().toIso8601String(),
    });
    
    // Keep only last 5 credentials
    if (credentials.length > 5) {
      credentials.removeRange(5, credentials.length);
    }
    
    // Save to preferences
    final credentialsJson = credentials.map((cred) => json.encode(cred)).toList();
    await _prefs?.setStringList(_savedCredentialsKey, credentialsJson);
  }
  
  Future<List<Map<String, String>>> getSavedCredentialsList() async {
    final credentialsJson = _prefs?.getStringList(_savedCredentialsKey) ?? [];
    return credentialsJson.map((credJson) {
      final Map<String, dynamic> decoded = json.decode(credJson);
      return Map<String, String>.from(decoded);
    }).toList();
  }
  
  // Legacy method for backward compatibility
  Future<Map<String, String?>> getSavedCredentials() async {
    final credentials = await getSavedCredentialsList();
    if (credentials.isEmpty) {
      return {'email': null, 'password': null};
    }
    return {
      'email': credentials.first['email'],
      'password': credentials.first['password'],
    };
  }
  
  Future<void> clearSavedCredentials() async {
    await _prefs?.remove(_savedCredentialsKey);
  }
  
  Future<void> deleteSavedCredential(String email) async {
    final credentials = await getSavedCredentialsList();
    credentials.removeWhere((cred) => cred['email'] == email);
    
    final credentialsJson = credentials.map((cred) => json.encode(cred)).toList();
    await _prefs?.setStringList(_savedCredentialsKey, credentialsJson);
  }

  // Forgot Password functionality
  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    print('🔐 === FORGOT PASSWORD PROCESS STARTED ===');
    print('📧 Requesting password reset for: $email');
    
    final url = Uri.parse('$_baseUrl/auth/forgot-password');
    print('🌐 API URL: $url');
    
    final requestBody = {
      'email': email,
    };
    
    print('📤 Forgot password request body: ${json.encode(requestBody)}');
    print('⏳ Sending request to server...');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 Forgot password response status: ${response.statusCode}');
      print('📥 Forgot password response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        print('✅ Password reset email sent successfully');
        print('📧 Reset instructions sent to: $email');
        print('🔐 === FORGOT PASSWORD PROCESS COMPLETED ===');
        
        return responseData;
      } else {
        print('❌ Forgot password failed with status: ${response.statusCode}');
        print('❌ Error message: ${responseData['message']}');
        throw Exception(responseData['message'] ?? 'Failed to send password reset email');
      }
    } catch (e) {
      print('💥 Forgot password error occurred: $e');
      print('🚨 Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  // Reset Password functionality
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    print('🔐 === RESET PASSWORD PROCESS STARTED ===');
    
    final url = Uri.parse('$_baseUrl/auth/reset-password');
    print('🌐 API URL: $url');
    
    final requestBody = {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    };
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 Reset password response status: ${response.statusCode}');
      print('📥 Reset password response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        print('✅ Password reset successful');
        print('🔐 === RESET PASSWORD PROCESS COMPLETED ===');
        return responseData;
      } else {
        print('❌ Reset password failed with status: ${response.statusCode}');
        throw Exception(responseData['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      print('💥 Reset password error occurred: $e');
      rethrow;
    }
  }

  // Check if user account is approved (ACTIVE status)
  bool get isAccountApproved => _currentUser?.status == UserStatus.ACTIVE;
  
  // Get user approval status message
  String getAccountStatusMessage() {
    if (_currentUser == null) return 'Not logged in';
    
    switch (_currentUser!.status) {
      case UserStatus.ACTIVE:
        return 'Account is active and approved';
      case UserStatus.INACTIVE:
        return 'Account is pending approval from administrator';
      case UserStatus.SUSPENDED:
        return 'Account has been suspended. Contact administrator';
      default:
        return 'Unknown account status';
    }
  }
}