class CrewMember {
  final String id;
  final String name;
  final String employeeId;
  final CrewRole role;
  final String phoneNumber;
  final String homeBase;
  final CrewStatus status;
  final DateTime? currentDutyStart;
  final String? currentTrainNumber;

  CrewMember({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.role,
    required this.phoneNumber,
    required this.homeBase,
    this.status = CrewStatus.available,
    this.currentDutyStart,
    this.currentTrainNumber,
  });

  bool get isOnDuty => status == CrewStatus.onDuty;
  
  Duration? get currentDutyDuration {
    if (currentDutyStart == null) return null;
    return DateTime.now().difference(currentDutyStart!);
  }

  bool get isApproachingLimit {
    final duration = currentDutyDuration;
    if (duration == null) return false;
    return duration.inHours >= 8;
  }

  bool get hasExceededLimit {
    final duration = currentDutyDuration;
    if (duration == null) return false;
    return duration.inHours >= 9;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'employeeId': employeeId,
      'role': role.toString(),
      'phoneNumber': phoneNumber,
      'homeBase': homeBase,
      'status': status.toString(),
      'currentDutyStart': currentDutyStart?.toIso8601String(),
      'currentTrainNumber': currentTrainNumber,
    };
  }

  factory CrewMember.fromJson(Map<String, dynamic> json) {
    return CrewMember(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      role: CrewRole.values.firstWhere(
        (e) => e.toString() == json['role']?.toString(),
        orElse: () => CrewRole.guard,
      ),
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      homeBase: json['homeBase']?.toString() ?? '',
      status: CrewStatus.values.firstWhere(
        (e) => e.toString() == json['status']?.toString(),
        orElse: () => CrewStatus.available,
      ),
      currentDutyStart: json['currentDutyStart'] != null
          ? DateTime.parse(json['currentDutyStart'].toString())
          : null,
      currentTrainNumber: json['currentTrainNumber']?.toString(),
    );
  }

  CrewMember copyWith({
    String? id,
    String? name,
    String? employeeId,
    CrewRole? role,
    String? phoneNumber,
    String? homeBase,
    CrewStatus? status,
    DateTime? currentDutyStart,
    String? currentTrainNumber,
  }) {
    return CrewMember(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      homeBase: homeBase ?? this.homeBase,
      status: status ?? this.status,
      currentDutyStart: currentDutyStart ?? this.currentDutyStart,
      currentTrainNumber: currentTrainNumber ?? this.currentTrainNumber,
    );
  }
}

enum CrewRole {
  guard,
  locoPilot,
  assistant,
}

enum CrewStatus {
  available,
  onDuty,
  offDuty,
  sick,
  leave,
}

extension CrewRoleExtension on CrewRole {
  String get displayName {
    switch (this) {
      case CrewRole.guard:
        return 'Guard';
      case CrewRole.locoPilot:
        return 'Loco Pilot';
      case CrewRole.assistant:
        return 'Assistant';
    }
  }
}

extension CrewStatusExtension on CrewStatus {
  String get displayName {
    switch (this) {
      case CrewStatus.available:
        return 'Available';
      case CrewStatus.onDuty:
        return 'On Duty';
      case CrewStatus.offDuty:
        return 'Off Duty';
      case CrewStatus.sick:
        return 'Sick';
      case CrewStatus.leave:
        return 'On Leave';
    }
  }
}
