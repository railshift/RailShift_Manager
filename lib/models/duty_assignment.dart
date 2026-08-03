import 'crew_member.dart';
import 'locomotive.dart';
import 'alert.dart';
import 'staff.dart';



class DutyAssignment {
  final String id;
  final String? backendShiftId; // Store the backend shift ID separately
  final String trainNumber;
  final String? trainName;
  final String? locomotiveNo;
  final String? locomotiveId;
  final Locomotive? locomotive; // Full locomotive object
  final DateTime? trainArrivalDate;
  final DateTime? trainArrivalTime;
  final DateTime? signOnTime;
  final String? signOnStation;
  final String? signOffStation;
  final DateTime? timeOfTO;
  final DateTime? departureTime;
  final CrewMemberInfo? locoPilot;
  final CrewMemberInfo? trainManager;
  final String? guardId;
  final String? assistantId;
  final String? section;
  final String? dutyType;
  final bool? lobbySignOn;
  final bool? lobbySignOff;
  final DateTime? signOffDate;
  final DateTime? signOffTime;
  final double? dutyHours;
  final bool reliefRequired;
  final bool reliefPlanned;
  final DateTime? reliefTime;
  final String? reliefReason;
  final DateTime startTime;
  final DateTime? endTime;
  final ShiftStatus status;
  final String? notes;
  final DateTime createdAt;
  final String createdBy; // Section Incharge ID
  
  // Alert-related fields
  final List<Alert>? alerts;
  final int alertCount;
  final DateTime? lastAlertTime;
  final AlertStatus? currentAlertStatus;
  final bool hasUnresolvedAlerts;
  
  // Legacy fields for backward compatibility
  final String? fromStation;
  final String? toStation;

  DutyAssignment({
    required this.id,
    this.backendShiftId,
    required this.trainNumber,
    this.trainName,
    this.locomotiveNo,
    this.locomotiveId,
    this.locomotive,
    this.trainArrivalDate,
    this.trainArrivalTime,
    this.signOnTime,
    this.signOnStation,
    this.signOffStation,
    this.timeOfTO,
    this.departureTime,
    this.locoPilot,
    this.trainManager,
    this.guardId,
    this.assistantId,
    this.section,
    this.dutyType,
    this.lobbySignOn,
    this.lobbySignOff,
    this.signOffDate,
    this.signOffTime,
    this.dutyHours,
    this.reliefRequired = false,
    this.reliefPlanned = false,
    this.reliefTime,
    this.reliefReason,
    this.fromStation,
    this.toStation,
    DateTime? startTime,
    this.endTime,
    this.status = ShiftStatus.IN_PROGRESS,
    this.notes,
    required this.createdAt,
    required this.createdBy,
    // Alert-related fields
    this.alerts,
    this.alertCount = 0,
    this.lastAlertTime,
    this.currentAlertStatus,
    this.hasUnresolvedAlerts = false,
  }) : startTime = startTime ?? signOnTime ?? departureTime ?? DateTime.now();

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  bool get isActive => status == ShiftStatus.IN_PROGRESS;
  bool get isCompleted => status == ShiftStatus.COMPLETED;
  bool get isOverdue => status == ShiftStatus.CANCELLED;

  bool get isApproachingLimit => duration.inHours >= 8;
  bool get hasExceededLimit => duration.inHours >= 9;

  /// Check if shift has critical alerts (9+ hours)
  bool get hasCriticalAlerts => duration.inHours >= 9 || hasUnresolvedAlerts;

  /// Get the most recent alert
  Alert? get latestAlert {
    if (alerts == null || alerts!.isEmpty) return null;
    return alerts!.reduce((a, b) => a.sentAt.isAfter(b.sentAt) ? a : b);
  }

  /// Get pending alerts count
  int get pendingAlertsCount {
    if (alerts == null) return 0;
    return alerts!.where((alert) => alert.status == AlertStatus.PENDING).length;
  }

  /// Get locomotive display name
  String get locomotiveDisplayName {
    if (locomotive != null) {
      return locomotive!.displayName;
    }
    return locomotiveNo ?? 'Unknown Locomotive';
  }

  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Map<String, dynamic> toJson() {
    return {
      'trainNumber': trainNumber,
      'trainName': trainName,
      'locomotiveNo': locomotiveNo,
      'locomotive': locomotive?.toJson(),
      'trainArrivalDate': trainArrivalDate != null ? trainArrivalDate!.toIso8601String() : null,
      'trainArrivalTime': trainArrivalTime != null ? trainArrivalTime!.toIso8601String() : null,
      'signOnTime': signOnTime != null ? signOnTime!.toIso8601String() : null,
      'timeOfTO': timeOfTO != null ? timeOfTO!.toIso8601String() : null,
      'departureTime': departureTime != null ? departureTime!.toIso8601String() : null,
      'locoPilot': locoPilot?.toJson(),
      'trainManager': trainManager?.toJson(),
      // Internal fields for local use
      'id': id,
      'backendShiftId': backendShiftId,
      'guardId': guardId,
      'assistantId': assistantId,
      'fromStation': fromStation,
      'toStation': toStation,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status.toString(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      // Alert-related fields
      'alerts': alerts?.map((alert) => alert.toJson()).toList(),
      'alertCount': alertCount,
      'lastAlertTime': lastAlertTime?.toIso8601String(),
      'currentAlertStatus': currentAlertStatus?.toString().split('.').last,
      'hasUnresolvedAlerts': hasUnresolvedAlerts,
    };
  }

  factory DutyAssignment.fromJson(Map<String, dynamic> json) {
    // Parse alerts if present
    List<Alert>? alerts;
    if (json['alerts'] != null) {
      final alertsData = json['alerts'] as List;
      alerts = alertsData.map((alertJson) => Alert.fromJson(alertJson)).toList();
    }

    return DutyAssignment(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      backendShiftId: json['backendShiftId']?.toString(),
      trainNumber: json['trainNumber']?.toString() ?? '',
      trainName: json['trainName']?.toString(),
      locomotiveNo: json['locomotiveNo']?.toString(),
      locomotive: json['locomotive'] != null ? Locomotive.fromJson(json['locomotive']) : null,
      trainArrivalDate: json['trainArrivalDate'] != null ? DateTime.parse(json['trainArrivalDate'].toString()) : null,
      trainArrivalTime: json['trainArrivalTime'] != null ? DateTime.parse(json['trainArrivalTime'].toString()) : null,
      signOnTime: json['signOnTime'] != null ? DateTime.parse(json['signOnTime'].toString()) : null,
      timeOfTO: json['timeOfTO'] != null ? DateTime.parse(json['timeOfTO'].toString()) : null,
      departureTime: json['departureTime'] != null ? DateTime.parse(json['departureTime'].toString()) : null,
      locoPilot: json['locoPilot'] != null ? CrewMemberInfo.fromJson(json['locoPilot']) : null,
      trainManager: json['trainManager'] != null ? CrewMemberInfo.fromJson(json['trainManager']) : null,
      guardId: json['guardId']?.toString(),
      assistantId: json['assistantId']?.toString(),
      fromStation: json['fromStation']?.toString(),
      toStation: json['toStation']?.toString(),
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime'].toString()) : DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'].toString()) : null,
      status: json['status'] != null ? _parseStatus(json['status']) : ShiftStatus.IN_PROGRESS,
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
      createdBy: json['createdBy']?.toString() ?? 'system',
      // Alert-related fields
      alerts: alerts,
      alertCount: (json['alertCount'] as num?)?.toInt() ?? alerts?.length ?? 0,
      lastAlertTime: json['lastAlertTime'] != null ? DateTime.parse(json['lastAlertTime'].toString()) : null,
      currentAlertStatus: json['currentAlertStatus'] != null 
          ? AlertStatus.values.firstWhere(
              (e) => e.toString().split('.').last == json['currentAlertStatus'],
              orElse: () => AlertStatus.PENDING,
            )
          : null,
      hasUnresolvedAlerts: json['hasUnresolvedAlerts'] as bool? ?? false,
    );
  }

  // Factory method specifically for backend payload format
  factory DutyAssignment.fromBackendPayload(Map<String, dynamic> json) {
    return DutyAssignment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      trainNumber: json['trainNumber'],
      trainName: json['trainName'],
      locomotiveNo: json['locomotiveNo'],
      trainArrivalDate: json['trainArrivalDate'] != null ? DateTime.parse(json['trainArrivalDate']) : null,
      trainArrivalTime: json['trainArrivalTime'] != null ? DateTime.parse(json['trainArrivalTime']) : null,
      signOnTime: json['signOnTime'] != null ? DateTime.parse(json['signOnTime']) : null,
      timeOfTO: json['timeOfTO'] != null ? DateTime.parse(json['timeOfTO']) : null,
      departureTime: json['departureTime'] != null ? DateTime.parse(json['departureTime']) : null,
      locoPilot: json['locoPilot'] != null ? CrewMemberInfo.fromJson(json['locoPilot']) : null,
      trainManager: json['trainManager'] != null ? CrewMemberInfo.fromJson(json['trainManager']) : null,
      startTime: json['signOnTime'] != null ? DateTime.parse(json['signOnTime']) : DateTime.now(),
      status: ShiftStatus.SCHEDULED,
      createdAt: DateTime.now(),
      createdBy: 'backend',
    );
  }

  // Method to convert to backend payload format (matches Prisma schema exactly)
  Map<String, dynamic> toBackendPayload() {
    print('🚀 Creating backend payload for shift:');
    print('  - Train Number: $trainNumber');
    print('  - Sign On Station: $signOnStation');
    print('  - Section: $section');
    print('  - Duty Type: $dutyType');
    
    // Backend expects documented v1 route fields.
    
    final payload = <String, dynamic>{
      'trainNumber': trainNumber,
      'trainName': trainName,
      'locomotiveNo': locomotiveNo ?? '',
      'signOnStation': signOnStation ?? fromStation ?? 'Unknown Station',
      'section': section ?? 'General',
      'dutyType': dutyType ?? 'SP',
    };
    

    // Helper to format DateTime as UTC ISO 8601 string
    String toUtcIso(DateTime dt) => dt.toUtc().toIso8601String();

    // Add REQUIRED DateTime fields using the new schema format
    payload['trainArrivalDateTime'] = toUtcIso(trainArrivalTime ?? DateTime.now());
    payload['signOnDateTime'] = toUtcIso(signOnTime ?? DateTime.now());
    
    // Add optional DateTime fields
    if (timeOfTO != null) {
      payload['timeOfTO'] = toUtcIso(timeOfTO!);
    }
    
    if (departureTime != null) {
      payload['departureDateTime'] = toUtcIso(departureTime!);
    }
    
    // Loco Pilot details
    if (locoPilot != null) {
      payload['locoPilot'] = {
        'employeeId': locoPilot!.employeeId,
        'name': locoPilot!.name,
        if (locoPilot!.phone.isNotEmpty) 'phone': locoPilot!.phone,
      };
    }
    
    // Train Manager details
    if (trainManager != null) {
      payload['trainManager'] = {
        'employeeId': trainManager!.employeeId,
        'name': trainManager!.name,
        if (trainManager!.phone.isNotEmpty) 'phone': trainManager!.phone,
      };
    }
    
    print('📤 Backend payload created: ${payload.toString()}');
    print('💡 Backend must handle auto-creation of Locomotive and Staff entities');
    
    return payload;
  }

  DutyAssignment copyWith({
    String? id,
    String? backendShiftId,
    String? trainNumber,
    String? trainName,
    String? locomotiveNo,
    Locomotive? locomotive,
    DateTime? trainArrivalDate,
    DateTime? trainArrivalTime,
    DateTime? signOnTime,
    DateTime? timeOfTO,
    DateTime? departureTime,
    CrewMemberInfo? locoPilot,
    CrewMemberInfo? trainManager,
    String? guardId,
    String? assistantId,
    String? fromStation,
    String? toStation,
    DateTime? startTime,
    DateTime? endTime,
    ShiftStatus? status,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
    List<Alert>? alerts,
    int? alertCount,
    DateTime? lastAlertTime,
    AlertStatus? currentAlertStatus,
    bool? hasUnresolvedAlerts,
  }) {
    return DutyAssignment(
      id: id ?? this.id,
      backendShiftId: backendShiftId ?? this.backendShiftId,
      trainNumber: trainNumber ?? this.trainNumber,
      trainName: trainName ?? this.trainName,
      locomotiveNo: locomotiveNo ?? this.locomotiveNo,
      locomotive: locomotive ?? this.locomotive,
      trainArrivalDate: trainArrivalDate ?? this.trainArrivalDate,
      trainArrivalTime: trainArrivalTime ?? this.trainArrivalTime,
      signOnTime: signOnTime ?? this.signOnTime,
      timeOfTO: timeOfTO ?? this.timeOfTO,
      departureTime: departureTime ?? this.departureTime,
      locoPilot: locoPilot ?? this.locoPilot,
      trainManager: trainManager ?? this.trainManager,
      guardId: guardId ?? this.guardId,
      assistantId: assistantId ?? this.assistantId,
      fromStation: fromStation ?? this.fromStation,
      toStation: toStation ?? this.toStation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      alerts: alerts ?? this.alerts,
      alertCount: alertCount ?? this.alertCount,
      lastAlertTime: lastAlertTime ?? this.lastAlertTime,
      currentAlertStatus: currentAlertStatus ?? this.currentAlertStatus,
      hasUnresolvedAlerts: hasUnresolvedAlerts ?? this.hasUnresolvedAlerts,
    );
  }

  // Helper method to parse status from different sources
  static ShiftStatus _parseStatus(dynamic statusValue) {
    if (statusValue is String) {
      // Handle API status values
      switch (statusValue.toUpperCase()) {
        case 'SCHEDULED':
          return ShiftStatus.SCHEDULED;
        case 'IN_PROGRESS':
          return ShiftStatus.IN_PROGRESS;
        case 'COMPLETED':
          return ShiftStatus.COMPLETED;
        case 'RELIEF_PLANNED':
          return ShiftStatus.RELIEF_PLANNED;
        case 'CANCELLED':
          return ShiftStatus.CANCELLED;
        // Handle legacy status values
        case 'DUTYSTATUS.ACTIVE':
        case 'ACTIVE':
          return ShiftStatus.IN_PROGRESS;
        case 'DUTYSTATUS.COMPLETED':
          return ShiftStatus.COMPLETED;
        case 'DUTYSTATUS.OVERDUE':
        case 'OVERDUE':
          return ShiftStatus.CANCELLED;
        case 'DUTYSTATUS.CANCELLED':
          return ShiftStatus.CANCELLED;
        default:
          return ShiftStatus.IN_PROGRESS;
      }
    }
    return ShiftStatus.IN_PROGRESS;
  }

  // Convenience getters for backward compatibility
  String? get locoPilotName => locoPilot?.name;
  String? get locoPilotId => locoPilot?.employeeId;
  String? get trainManagerName => trainManager?.name;
  String? get trainManagerId => trainManager?.employeeId;
  String? get trainManagerPhone => trainManager?.phone;
  
  // Legacy status compatibility
  DutyStatus get legacyStatus {
    switch (status) {
      case ShiftStatus.IN_PROGRESS:
      case ShiftStatus.SCHEDULED:
        return DutyStatus.active;
      case ShiftStatus.COMPLETED:
        return DutyStatus.completed;
      case ShiftStatus.CANCELLED:
        return DutyStatus.cancelled;
      case ShiftStatus.RELIEF_PLANNED:
        return DutyStatus.overdue;
    }
  }
}

enum ShiftStatus {
  SCHEDULED,
  IN_PROGRESS,
  COMPLETED,
  RELIEF_PLANNED,
  CANCELLED,
}

enum DutyType {
  SP,
  WR,
  LR,
}

// Keep old enum for backward compatibility
enum DutyStatus {
  active,
  completed,
  overdue,
  cancelled,
}

extension DutyStatusExtension on DutyStatus {
  String get displayName {
    switch (this) {
      case DutyStatus.active:
        return 'Active';
      case DutyStatus.completed:
        return 'Completed';
      case DutyStatus.overdue:
        return 'Overdue';
      case DutyStatus.cancelled:
        return 'Cancelled';
    }
  }
}

extension ShiftStatusExtension on ShiftStatus {
  String get displayName {
    switch (this) {
      case ShiftStatus.SCHEDULED:
        return 'Scheduled';
      case ShiftStatus.IN_PROGRESS:
        return 'In Progress';
      case ShiftStatus.COMPLETED:
        return 'Completed';
      case ShiftStatus.RELIEF_PLANNED:
        return 'Relief Planned';
      case ShiftStatus.CANCELLED:
        return 'Cancelled';
    }
  }
}

extension DutyTypeExtension on DutyType {
  String get displayName {
    switch (this) {
      case DutyType.SP:
        return 'SP'; // As per API documentation
      case DutyType.WR:
        return 'WR'; // As per API documentation  
      case DutyType.LR:
        return 'LR'; // As per API documentation
    }
  }
}

class DutySearchFilter {
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final DutyStatus? status; // Keep for backward compatibility
  final ShiftStatus? shiftStatus;
  final String? trainNumber;
  final String? crewMemberId;

  DutySearchFilter({
    this.searchQuery,
    this.startDate,
    this.endDate,
    this.status,
    this.shiftStatus,
    this.trainNumber,
    this.crewMemberId,
  });

  bool matches(DutyAssignment duty, List<CrewMember> crewMembers) {
    // Search query check
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      final guard = duty.guardId != null ? crewMembers.where((c) => c.id == duty.guardId).firstOrNull : null;
      
      if (!duty.trainNumber.toLowerCase().contains(query) &&
          (guard == null || !guard.name.toLowerCase().contains(query)) &&
          (duty.locoPilot?.name.toLowerCase().contains(query) != true) &&
          (duty.trainManager?.name.toLowerCase().contains(query) != true) &&
          (duty.fromStation?.toLowerCase().contains(query) != true) &&
          (duty.toStation?.toLowerCase().contains(query) != true)) {
        return false;
      }
    }

    // Date range check
    if (startDate != null && duty.startTime.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null && duty.startTime.isAfter(endDate!)) {
      return false;
    }

    // Status check (handle both old and new status types)
    if (shiftStatus != null && duty.status != shiftStatus) {
      return false;
    }
    if (status != null && duty.legacyStatus != status) {
      return false;
    }

    // Train number check
    if (trainNumber != null && 
        !duty.trainNumber.toLowerCase().contains(trainNumber!.toLowerCase())) {
      return false;
    }

    // Crew member check
    if (crewMemberId != null && 
        duty.guardId != crewMemberId && 
        duty.locoPilot?.employeeId != crewMemberId &&
        duty.trainManager?.employeeId != crewMemberId &&
        duty.assistantId != crewMemberId) {
      return false;
    }

    return true;
  }
}
