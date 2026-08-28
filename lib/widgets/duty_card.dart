import 'package:flutter/material.dart';
import '../models/crew_member.dart';
import '../models/duty_assignment.dart';
import '../screens/duty_detail_screen.dart';
import '../theme/app_theme.dart';

class DutyCard extends StatelessWidget {
  final DutyAssignment duty;
  final List<CrewMember> crewMembers;
  final bool isDarkMode;
  final VoidCallback onRefresh;

  const DutyCard({
    super.key,
    required this.duty,
    required this.crewMembers,
    required this.isDarkMode,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Safely get crew members, handle cases where they might not be found locally
    final guard = crewMembers.where((c) => c.id == duty.guardId).isNotEmpty
        ? crewMembers.firstWhere((c) => c.id == duty.guardId)
        : CrewMember(
            id: duty.guardId ?? 'unknown',
            name: duty.trainManager?.name ?? 'Guard (${duty.guardId ?? 'unknown'})',
            employeeId: duty.trainManager?.employeeId ?? duty.guardId ?? 'unknown',
            role: CrewRole.guard,
            phoneNumber: duty.trainManager?.phone ?? '',
            homeBase: 'Unknown',
            status: CrewStatus.onDuty,
          );

    final pilot = duty.locoPilot != null
        ? CrewMember(
            id: 'pilot_${duty.id}',
            name: duty.locoPilot!.name,
            employeeId: duty.locoPilot!.employeeId,
            role: CrewRole.locoPilot,
            phoneNumber: duty.locoPilot!.phone,
            homeBase: 'Unknown',
            status: CrewStatus.onDuty,
          )
        : (crewMembers.where((c) => c.id == duty.locoPilotId).isNotEmpty
            ? crewMembers.firstWhere((c) => c.id == duty.locoPilotId)
            : CrewMember(
                id: duty.locoPilotId ?? 'unknown_pilot',
                name: 'Loco Pilot',
                employeeId: duty.locoPilotId ?? 'unknown',
                role: CrewRole.locoPilot,
                phoneNumber: '',
                homeBase: 'Unknown',
                status: CrewStatus.onDuty,
              ));

    final assistant = duty.assistantId != null && crewMembers.where((c) => c.id == duty.assistantId).isNotEmpty
        ? crewMembers.firstWhere((c) => c.id == duty.assistantId)
        : null;

    final duration = duty.duration;
    final durationColor = AppTheme.getDurationColor(duration);
    final statusColor = AppTheme.getStatusColor(duty.status.displayName);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DutyDetailScreen(
              duty: duty,
              crewMembers: crewMembers,
            ),
          ),
        ).then((result) {
          // Refresh data if duty was ended
          if (result == true) {
            onRefresh();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    AppTheme.cardBackground,
                    AppTheme.cardBackground.withOpacity(0.9),
                  ]
                : [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: statusColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentOrange,
                          AppTheme.accentOrange.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentOrange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.train_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Train ${duty.trainNumber}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: isDarkMode
                                  ? AppTheme.textSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                duty.section ?? '${duty.fromStation} → ${duty.toStation}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isDarkMode
                                          ? AppTheme.textSecondary
                                          : AppTheme.lightTextSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          duty.status.displayName,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              durationColor,
                              durationColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${duration.inHours}h ${duration.inMinutes % 60}m',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppTheme.surfaceColor.withOpacity(0.5)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CrewInfoTile(
                        role: 'Guard',
                        name: guard.name,
                        icon: Icons.security_rounded,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
                    ),
                    Expanded(
                      child: CrewInfoTile(
                        role: 'Loco Pilot',
                        name: pilot.name,
                        icon: Icons.person_rounded,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    if (assistant != null) ...[
                      Container(
                        width: 1,
                        height: 32,
                        color: isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
                      ),
                      Expanded(
                        child: CrewInfoTile(
                          role: 'Assistant',
                          name: assistant.name,
                          icon: Icons.person_outline_rounded,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: isDarkMode
                              ? AppTheme.textSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            duty.endTime == null
                                ? 'Started: ${duty.startTime.hour.toString().padLeft(2, '0')}:${duty.startTime.minute.toString().padLeft(2, '0')}'
                                : 'Started: ${duty.startTime.hour.toString().padLeft(2, '0')}:${duty.startTime.minute.toString().padLeft(2, '0')}  •  Ended: ${duty.endTime!.hour.toString().padLeft(2, '0')}:${duty.endTime!.minute.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode
                                      ? AppTheme.textSecondary
                                      : AppTheme.lightTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (duty.notes != null && duty.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.accentOrange.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note_rounded,
                        size: 16,
                        color: AppTheme.accentOrange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          duty.notes!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CrewInfoTile extends StatelessWidget {
  final String role;
  final String name;
  final IconData icon;
  final bool isDarkMode;

  const CrewInfoTile({
    super.key,
    required this.role,
    required this.name,
    required this.icon,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppTheme.accentOrange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            role,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}