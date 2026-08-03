// Alert model aligned with backend API docs (GET /alerts, GET /shifts/:id/alerts)
// API Base: https://api.dutyhours.in/api/v1

class Alert {
  final String id;
  final String shiftId;
  final AlertType type;
  final String title;
  final String message;
  final AlertStatus status;
  final DateTime sentAt;
  final DateTime? acknowledgedAt;
  final String? responseAction;
  /// Integer priority from API (1 = highest)
  final int priority;
  final DateTime? createdAt;
  /// Embedded shift reference returned by GET /alerts
  final AlertShiftRef? shift;

  // Legacy / per-shift-alert fields (from GET /shifts/:id/alerts → alertHistory)
  final bool? requiresAction;

  Alert({
    required this.id,
    required this.shiftId,
    required this.type,
    required this.title,
    required this.message,
    required this.status,
    required this.sentAt,
    this.acknowledgedAt,
    this.responseAction,
    this.priority = 1,
    this.createdAt,
    this.shift,
    this.requiresAction,
  });

  /// Parse from GET /alerts response item
  factory Alert.fromJson(Map<String, dynamic> json) {
    String rawMessage = json['message']?.toString() ?? '';
    final trainNumber = json['shift']?['trainNumber']?.toString();
    
    if (trainNumber != null && trainNumber.isNotEmpty) {
      rawMessage = rawMessage.replaceAll('for null', 'for Train $trainNumber');
    } else {
      rawMessage = rawMessage.replaceAll('for null ', '');
    }

    return Alert(
      id: json['id']?.toString() ?? '',
      shiftId: json['shiftId']?.toString() ?? '',
      type: alertTypeFromApiValue(json['type']?.toString()),
      title: json['title']?.toString() ?? _defaultTitle(json['type']?.toString()),
      message: rawMessage,
      status: alertStatusFromString(json['status']?.toString()),
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'].toString())
          : (json['triggeredAt'] != null
              ? DateTime.parse(json['triggeredAt'].toString())
              : (json['createdAt'] != null
                  ? DateTime.parse(json['createdAt'].toString())
                  : DateTime.now())),
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.parse(json['acknowledgedAt'].toString())
          : null,
      responseAction: json['responseAction']?.toString() ?? json['response']?.toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : null,
      shift: json['shift'] != null
          ? AlertShiftRef.fromJson(json['shift'] as Map<String, dynamic>)
          : null,
      requiresAction: json['requiresAction'] as bool?,
    );
  }

  /// Parse from GET /shifts/:id/alerts → data.alertHistory item
  factory Alert.fromShiftAlertHistory(Map<String, dynamic> json, String shiftId) {
    final typeStr = json['type']?.toString();
    return Alert(
      id: json['id']?.toString() ?? '${shiftId}_$typeStr',
      shiftId: shiftId,
      type: alertTypeFromApiValue(typeStr),
      title: _defaultTitle(typeStr),
      message: 'Alert: $typeStr',
      status: alertStatusFromString(json['status']?.toString()),
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'].toString())
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'].toString())
              : DateTime.now()),
      responseAction: json['response']?.toString(),
      requiresAction: json['requiresAction'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shiftId': shiftId,
      'type': type.apiValue,
      'title': title,
      'message': message,
      'status': status.apiValue,
      'sentAt': sentAt.toIso8601String(),
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'responseAction': responseAction,
      'priority': priority,
      'createdAt': createdAt?.toIso8601String(),
      'shift': shift?.toJson(),
      'requiresAction': requiresAction,
    };
  }

  Alert copyWith({
    String? id,
    String? shiftId,
    AlertType? type,
    String? title,
    String? message,
    AlertStatus? status,
    DateTime? sentAt,
    DateTime? acknowledgedAt,
    String? responseAction,
    int? priority,
    DateTime? createdAt,
    AlertShiftRef? shift,
    bool? requiresAction,
  }) {
    return Alert(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      responseAction: responseAction ?? this.responseAction,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      shift: shift ?? this.shift,
      requiresAction: requiresAction ?? this.requiresAction,
    );
  }

  // ── Convenience getters ──────────────────────────────────────────────────

  bool get isPending => status == AlertStatus.PENDING || status == AlertStatus.SENT;
  bool get isAcknowledged => status == AlertStatus.ACKNOWLEDGED;
  bool get isFailed => status == AlertStatus.FAILED;
  bool get isCritical => type == AlertType.DUTY_10HR || type == AlertType.DUTY_12HR || priority <= 1;

  bool get isOverdue {
    if (!isPending) return false;
    return DateTime.now().difference(sentAt).inHours > 2;
  }

  Duration get timeSinceSent => DateTime.now().difference(sentAt);

  String get timeSinceSentFormatted {
    final d = timeSinceSent;
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h ago';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m ago';
    return '${d.inMinutes}m ago';
  }

  String get typeDisplayName {
    switch (type) {
      case AlertType.DUTY_8HR:  return '8 Hour Alert';
      case AlertType.DUTY_10HR: return '10 Hour Alert';
      case AlertType.DUTY_12HR: return '12 Hour Alert';
      case AlertType.RELIEF_PLANNED: return 'Relief Planned';
      case AlertType.SHIFT_COMPLETED: return 'Shift Completed';
      case AlertType.CUSTOM:    return 'Custom Alert';
      case AlertType.UNKNOWN:   return 'Alert';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case AlertStatus.PENDING:      return 'Pending';
      case AlertStatus.SENT:         return 'Sent';
      case AlertStatus.ACKNOWLEDGED: return 'Acknowledged';
      case AlertStatus.FAILED:       return 'Failed';
    }
  }
}

// ── Embedded shift reference returned by GET /alerts ──────────────────────

class AlertShiftRef {
  final String id;
  final String trainNumber;
  final DateTime signOnDateTime;
  final String? status;

  AlertShiftRef({
    required this.id,
    required this.trainNumber,
    required this.signOnDateTime,
    this.status,
  });

  factory AlertShiftRef.fromJson(Map<String, dynamic> json) {
    return AlertShiftRef(
      id: json['id']?.toString() ?? '',
      trainNumber: json['trainNumber']?.toString() ?? '',
      signOnDateTime: json['signOnDateTime'] != null
          ? DateTime.parse(json['signOnDateTime'].toString())
          : DateTime.now(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trainNumber': trainNumber,
    'signOnDateTime': signOnDateTime.toIso8601String(),
    'status': status,
  };
}

// ── Enums ──────────────────────────────────────────────────────────────────

/// Alert types as returned by GET /alerts (type field)
enum AlertType {
  DUTY_8HR,
  DUTY_10HR,
  DUTY_12HR,
  RELIEF_PLANNED,
  SHIFT_COMPLETED,
  CUSTOM,
  UNKNOWN,
}

/// Alert statuses as returned by GET /alerts (status field)
enum AlertStatus {
  PENDING,
  SENT,
  ACKNOWLEDGED,
  FAILED,
}

// ── API value extensions ───────────────────────────────────────────────────

extension AlertTypeExt on AlertType {
  /// Used when reading/writing alert type from GET /alerts response.
  String get apiValue {
    switch (this) {
      case AlertType.DUTY_8HR:        return 'DUTY_8HR';
      case AlertType.DUTY_10HR:       return 'DUTY_10HR';
      case AlertType.DUTY_12HR:       return 'DUTY_12HR';
      case AlertType.RELIEF_PLANNED:  return 'RELIEF_PLANNED';
      case AlertType.SHIFT_COMPLETED: return 'SHIFT_COMPLETED';
      case AlertType.CUSTOM:          return 'CUSTOM';
      case AlertType.UNKNOWN:         return 'UNKNOWN';
    }
  }

  /// Used when sending POST /shifts/:id/alert-response.
  /// The alert-response endpoint uses a DIFFERENT type naming scheme
  /// ('8HR', '9HR', '10HR', '11HR', '14HR') from GET /alerts ('DUTY_8HR' etc.).
  String get alertResponseApiValue {
    switch (this) {
      case AlertType.DUTY_8HR:        return '8HR';
      case AlertType.DUTY_10HR:       return '10HR';
      case AlertType.DUTY_12HR:       return '11HR'; // closest match in endpoint spec
      case AlertType.RELIEF_PLANNED:  return '10HR'; // fallback
      case AlertType.SHIFT_COMPLETED: return '10HR'; // fallback
      case AlertType.CUSTOM:          return '8HR';  // fallback
      case AlertType.UNKNOWN:         return '8HR';  // fallback
    }
  }
}

extension AlertStatusExt on AlertStatus {
  String get apiValue {
    switch (this) {
      case AlertStatus.PENDING:      return 'PENDING';
      case AlertStatus.SENT:         return 'SENT';
      case AlertStatus.ACKNOWLEDGED: return 'ACKNOWLEDGED';
      case AlertStatus.FAILED:       return 'FAILED';
    }
  }
}

// ── Alert response type (UI-only enum) ────────────────────────────────────
// Used by the response dialog to let the user pick an action.
// Maps to the string values accepted by POST /shifts/:id/alert-response → response field.
enum AlertResponseType {
  ACKNOWLEDGE,      // → 'ACKNOWLEDGE'
  RELIEF_REQUESTED, // → 'PLAN_RELIEF'
  CONTINUING_DUTY,  // → 'KEEP_ON_DUTY'
  ESCALATE,         // → 'ESCALATE'
  RESOLVED,         // → 'CREW_RELIEVED'
}

// ── Parse helpers ──────────────────────────────────────────────────────────

AlertType alertTypeFromApiValue(String? value) {
  switch (value?.toUpperCase()) {
    case 'DUTY_8HR':
    // legacy variants still accepted for backward compat
    case '8HR':
    case 'ALERT_8HR':
    case 'HR_8':
      return AlertType.DUTY_8HR;

    case 'DUTY_10HR':
    case '10HR':
    case 'ALERT_10HR':
    case 'HR_10':
      return AlertType.DUTY_10HR;

    case 'DUTY_12HR':
    case '12HR':
    case 'ALERT_12HR':
    case 'HR_12':
    // Map old 9HR/11HR/14HR to nearest new type
    case '9HR':
    case 'ALERT_9HR':
    case 'HR_9':
    case '11HR':
    case 'ALERT_11HR':
    case 'HR_11':
    case '14HR':
    case 'ALERT_14HR':
    case 'HR_14':
      return AlertType.DUTY_12HR;

    case 'RELIEF_PLANNED':
    case 'RELIEF_REQUIRED':
      return AlertType.RELIEF_PLANNED;

    case 'SHIFT_COMPLETED':
      return AlertType.SHIFT_COMPLETED;

    case 'CUSTOM':
      return AlertType.CUSTOM;

    default:
      return AlertType.UNKNOWN;
  }
}

AlertStatus alertStatusFromString(String? value) {
  switch (value?.toUpperCase()) {
    case 'PENDING':      return AlertStatus.PENDING;
    case 'SENT':         return AlertStatus.SENT;
    case 'ACKNOWLEDGED': return AlertStatus.ACKNOWLEDGED;
    case 'FAILED':       return AlertStatus.FAILED;
    // legacy mappings
    case 'RESOLVED':
    case 'ESCALATED':
      return AlertStatus.ACKNOWLEDGED;
    default:
      return AlertStatus.PENDING;
  }
}

// ── Default title helper ───────────────────────────────────────────────────

String _defaultTitle(String? typeStr) {
  switch (typeStr?.toUpperCase()) {
    case 'DUTY_8HR':        return '8 Hour Duty Exceeded';
    case 'DUTY_10HR':       return '10 Hour Duty Exceeded';
    case 'DUTY_12HR':       return '12 Hour Duty Exceeded';
    case 'RELIEF_PLANNED':  return 'Relief Planned';
    case 'SHIFT_COMPLETED': return 'Shift Completed';
    case 'CUSTOM':          return 'Custom Alert';
    default:                return 'Duty Alert';
  }
}