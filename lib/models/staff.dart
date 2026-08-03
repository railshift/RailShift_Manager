class Staff {
  final String id;
  final String employeeId;
  final String name;
  final StaffType staffType;
  final String? phone;
  final String? email;
  final String? division;
  final String? section;
  final StaffStatus status;
  final DateTime? lastDutyDate;
  final double? totalDutyHours;
  final int? totalShifts;
  final Map<String, dynamic>? qualifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  Staff({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.staffType,
    this.phone,
    this.email,
    this.division,
    this.section,
    required this.status,
    this.lastDutyDate,
    this.totalDutyHours,
    this.totalShifts,
    this.qualifications,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      staffType: StaffType.values.firstWhere(
        (e) => e.toString().split('.').last == json['staffType']?.toString(),
        orElse: () => StaffType.LOCO_PILOT,
      ),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      division: json['division']?.toString(),
      section: json['section']?.toString(),
      status: StaffStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status']?.toString(),
        orElse: () => StaffStatus.OFF_DUTY,
      ),
      lastDutyDate: json['lastDutyDate'] != null 
          ? DateTime.parse(json['lastDutyDate'].toString()) 
          : null,
      totalDutyHours: (json['totalDutyHours'] as num?)?.toDouble(),
      totalShifts: (json['totalShifts'] as num?)?.toInt(),
      qualifications: json['qualifications'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'name': name,
      'staffType': staffType.toString().split('.').last,
      'phone': phone,
      'email': email,
      'division': division,
      'section': section,
      'status': status.toString().split('.').last,
      'lastDutyDate': lastDutyDate?.toIso8601String(),
      'totalDutyHours': totalDutyHours,
      'totalShifts': totalShifts,
      'qualifications': qualifications,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy of this staff with updated fields
  Staff copyWith({
    String? id,
    String? employeeId,
    String? name,
    StaffType? staffType,
    String? phone,
    String? email,
    String? division,
    String? section,
    StaffStatus? status,
    DateTime? lastDutyDate,
    double? totalDutyHours,
    int? totalShifts,
    Map<String, dynamic>? qualifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Staff(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      staffType: staffType ?? this.staffType,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      division: division ?? this.division,
      section: section ?? this.section,
      status: status ?? this.status,
      lastDutyDate: lastDutyDate ?? this.lastDutyDate,
      totalDutyHours: totalDutyHours ?? this.totalDutyHours,
      totalShifts: totalShifts ?? this.totalShifts,
      qualifications: qualifications ?? this.qualifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to CrewMemberInfo for backward compatibility
  CrewMemberInfo toCrewMemberInfo() {
    return CrewMemberInfo(
      employeeId: employeeId,
      name: name,
      phone: phone ?? '',
    );
  }

  /// Check if staff is available for duty
  bool get isAvailable => status == StaffStatus.OFF_DUTY;

  /// Check if staff is currently on duty
  bool get isOnDuty => status == StaffStatus.ON_DUTY;

  /// Get display name with staff type
  String get displayName {
    return '$name (${staffType.displayName})';
  }

  /// Get average duty hours per shift
  double get averageDutyHours {
    if (totalShifts == null || totalShifts == 0 || totalDutyHours == null) {
      return 0.0;
    }
    return totalDutyHours! / totalShifts!;
  }
}

/// Create CrewMemberInfo class for backward compatibility
class CrewMemberInfo {
  final String employeeId;
  final String name;
  final String phone;

  CrewMemberInfo({
    required this.employeeId,
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'name': name,
      'phone': phone,
    };
  }

  factory CrewMemberInfo.fromJson(Map<String, dynamic> json) {
    return CrewMemberInfo(
      employeeId: json['employeeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }

  /// Create from Staff object
  factory CrewMemberInfo.fromStaff(Staff staff) {
    return CrewMemberInfo(
      employeeId: staff.employeeId,
      name: staff.name,
      phone: staff.phone ?? '',
    );
  }
}

enum StaffType {
  LOCO_PILOT,
  TRAIN_MANAGER,
  GUARD,
  ASSISTANT,
  SECTION_INCHARGE,
}

enum StaffStatus {
  ON_DUTY,
  OFF_DUTY,
  ON_LEAVE,
  SUSPENDED,
  RETIRED,
}

extension StaffTypeExtension on StaffType {
  String get displayName {
    switch (this) {
      case StaffType.LOCO_PILOT:
        return 'Loco Pilot';
      case StaffType.TRAIN_MANAGER:
        return 'Train Manager';
      case StaffType.GUARD:
        return 'Guard';
      case StaffType.ASSISTANT:
        return 'Assistant';
      case StaffType.SECTION_INCHARGE:
        return 'Section Incharge';
    }
  }
}

extension StaffStatusExtension on StaffStatus {
  String get displayName {
    switch (this) {
      case StaffStatus.ON_DUTY:
        return 'On Duty';
      case StaffStatus.OFF_DUTY:
        return 'Off Duty';
      case StaffStatus.ON_LEAVE:
        return 'On Leave';
      case StaffStatus.SUSPENDED:
        return 'Suspended';
      case StaffStatus.RETIRED:
        return 'Retired';
    }
  }
}