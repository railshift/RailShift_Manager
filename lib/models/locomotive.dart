class Locomotive {
  final String id;
  final String locomotiveNo;
  final String? model;
  final String? type;
  final LocomotiveStatus status;
  final String? currentLocation;
  final DateTime? lastMaintenance;
  final DateTime? nextMaintenance;
  final Map<String, dynamic>? specifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  Locomotive({
    required this.id,
    required this.locomotiveNo,
    this.model,
    this.type,
    required this.status,
    this.currentLocation,
    this.lastMaintenance,
    this.nextMaintenance,
    this.specifications,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Locomotive.fromJson(Map<String, dynamic> json) {
    return Locomotive(
      id: json['id']?.toString() ?? '',
      locomotiveNo: json['locomotiveNo']?.toString() ?? '',
      model: json['model']?.toString(),
      type: json['type']?.toString(),
      status: LocomotiveStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status']?.toString(),
        orElse: () => LocomotiveStatus.ACTIVE,
      ),
      currentLocation: json['currentLocation']?.toString(),
      lastMaintenance: json['lastMaintenance'] != null 
          ? DateTime.parse(json['lastMaintenance'].toString()) 
          : null,
      nextMaintenance: json['nextMaintenance'] != null 
          ? DateTime.parse(json['nextMaintenance'].toString()) 
          : null,
      specifications: json['specifications'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'locomotiveNo': locomotiveNo,
      'model': model,
      'type': type,
      'status': status.toString().split('.').last,
      'currentLocation': currentLocation,
      'lastMaintenance': lastMaintenance?.toIso8601String(),
      'nextMaintenance': nextMaintenance?.toIso8601String(),
      'specifications': specifications,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy of this locomotive with updated fields
  Locomotive copyWith({
    String? id,
    String? locomotiveNo,
    String? model,
    String? type,
    LocomotiveStatus? status,
    String? currentLocation,
    DateTime? lastMaintenance,
    DateTime? nextMaintenance,
    Map<String, dynamic>? specifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Locomotive(
      id: id ?? this.id,
      locomotiveNo: locomotiveNo ?? this.locomotiveNo,
      model: model ?? this.model,
      type: type ?? this.type,
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      lastMaintenance: lastMaintenance ?? this.lastMaintenance,
      nextMaintenance: nextMaintenance ?? this.nextMaintenance,
      specifications: specifications ?? this.specifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if locomotive is available for duty
  bool get isAvailable => status == LocomotiveStatus.ACTIVE;

  /// Check if locomotive needs maintenance
  bool get needsMaintenance {
    if (nextMaintenance == null) return false;
    return DateTime.now().isAfter(nextMaintenance!);
  }

  /// Get display name for locomotive
  String get displayName {
    if (model != null && model!.isNotEmpty) {
      return '$locomotiveNo ($model)';
    }
    return locomotiveNo;
  }
}

enum LocomotiveStatus {
  ACTIVE,
  MAINTENANCE,
  OUT_OF_SERVICE,
  RETIRED,
}

extension LocomotiveStatusExtension on LocomotiveStatus {
  String get displayName {
    switch (this) {
      case LocomotiveStatus.ACTIVE:
        return 'Active';
      case LocomotiveStatus.MAINTENANCE:
        return 'Under Maintenance';
      case LocomotiveStatus.OUT_OF_SERVICE:
        return 'Out of Service';
      case LocomotiveStatus.RETIRED:
        return 'Retired';
    }
  }
}