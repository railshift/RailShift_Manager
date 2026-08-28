import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../theme/app_theme.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onViewShift;
  final String timeAgo;
  final String formattedDateTime;

  const AlertCard({
    super.key,
    required this.alert,
    required this.isDarkMode,
    required this.onTap,
    this.onAcknowledge,
    this.onViewShift,
    required this.timeAgo,
    required this.formattedDateTime,
  });

  Color _getAlertColor() {
    switch (alert.type) {
      case AlertType.DUTY_8HR:
        return const Color(0xFFF59E0B); // Amber
      case AlertType.DUTY_10HR:
        return const Color(0xFFDC2626); // Red
      case AlertType.DUTY_12HR:
        return const Color(0xFF7F1D1D); // Very Dark Red
      case AlertType.RELIEF_PLANNED:
        return const Color(0xFF7C3AED); // Purple
      case AlertType.SHIFT_COMPLETED:
        return const Color(0xFF059669); // Green
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getStatusColor() {
    switch (alert.status) {
      case AlertStatus.PENDING:
        return const Color(0xFFEA580C);
      case AlertStatus.SENT:
        return const Color(0xFFF59E0B);
      case AlertStatus.ACKNOWLEDGED:
        return const Color(0xFF2563EB);
      case AlertStatus.FAILED:
        return const Color(0xFFDC2626);
    }
  }

  IconData _getAlertIcon() {
    switch (alert.type) {
      case AlertType.DUTY_8HR:
        return Icons.schedule_outlined;
      case AlertType.DUTY_10HR:
        return Icons.error_outline;
      case AlertType.DUTY_12HR:
        return Icons.report_problem_outlined;
      case AlertType.RELIEF_PLANNED:
        return Icons.directions_run_outlined;
      case AlertType.SHIFT_COMPLETED:
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertColor = _getAlertColor();
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode 
                ? [const Color(0xFF1A1F2E), const Color(0xFF2A2F3E)]
                : [Colors.white, const Color(0xFFFAFBFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: alertColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: alertColor.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alert header with enhanced design
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: alertColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getAlertIcon(),
                          color: alertColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: alertColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    alert.typeDisplayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor, width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        alert.statusDisplayName,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Show title if it differs from typeDisplayName
                            if (alert.title.isNotEmpty)
                              Text(
                                alert.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Alert message with better typography
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black87,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Time information
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sent $timeAgo',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formattedDateTime,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  
                  // Action buttons for actionable alerts (PENDING or SENT)
                  if (alert.isPending && onAcknowledge != null && onViewShift != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onAcknowledge,
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Acknowledge'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onViewShift,
                            icon: const Icon(Icons.visibility_rounded, size: 18),
                            label: const Text('View Shift'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
