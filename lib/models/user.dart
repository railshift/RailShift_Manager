class User {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String? phone;
  final String? division;
  final String? designation;
  final UserRole role;
  final UserStatus status;
  final int priority;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;
  final String? profileImage;
  final Map<String, dynamic>? metadata;

  User({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    this.phone,
    this.division,
    this.designation,
    required this.role,
    required this.status,
    this.priority = 0,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
    this.profileImage,
    this.metadata,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      division: json['division']?.toString(),
      designation: json['designation']?.toString(),
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role']?.toString(),
        orElse: () => UserRole.USER,
      ),
      status: UserStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status']?.toString(),
        orElse: () => UserStatus.INACTIVE, // Default to INACTIVE for new registrations
      ),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString()) 
          : DateTime.parse(json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin'].toString()) : null,
      profileImage: json['profileImage']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'phone': phone,
      'division': division,
      'designation': designation,
      'role': role.toString().split('.').last,
      'status': status.toString().split('.').last,
      'priority': priority,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'profileImage': profileImage,
      'metadata': metadata,
    };
  }

  /// Create a copy of this user with updated fields
  User copyWith({
    String? id,
    String? employeeId,
    String? name,
    String? email,
    String? phone,
    String? division,
    String? designation,
    UserRole? role,
    UserStatus? status,
    int? priority,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
    String? profileImage,
    Map<String, dynamic>? metadata,
  }) {
    return User(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      division: division ?? this.division,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      profileImage: profileImage ?? this.profileImage,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if user has administrative privileges
  bool get isAdmin => role == UserRole.ADMIN || role == UserRole.SUPERADMIN;

  /// Check if user is active and verified
  bool get isActiveAndVerified => status == UserStatus.ACTIVE && isVerified;

  /// Get display name with designation if available
  String get displayName {
    if (designation != null && designation!.isNotEmpty) {
      return '$name ($designation)';
    }
    return name;
  }
}

enum UserRole {
  USER,
  ADMIN,
  SUPERADMIN,
}

enum UserStatus {
  ACTIVE,
  INACTIVE,
  SUSPENDED,
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}