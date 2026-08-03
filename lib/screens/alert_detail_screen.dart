import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/alert.dart';
import '../models/duty_assignment.dart';
import '../services/shift_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'alert_management_screen.dart';
import 'duty_detail_screen.dart';

/// Focused single-alert screen opened when a user taps a push notification.
/// Shows exactly the alert that was tapped with clear action buttons.
class AlertDetailScreen extends StatefulWidget {
  final String shiftId;
  final String alertId;

  const AlertDetailScreen({
    super.key,
    required this.shiftId,
    required this.alertId,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen>
    with SingleTickerProviderStateMixin {
  final ShiftService _shiftService = ShiftService();
  final NotificationService _notificationService = NotificationService();

  Alert? _alert;
  bool _isLoading = true;
  bool _isAcknowledging = false;
  bool _acknowledged = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _fetchAlert();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchAlert() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all pending alerts and find the one matching our alertId
      final response = await _shiftService.getPendingAlerts();
      final allAlerts = (response['data'] as List? ?? [])
          .map((data) => Alert.fromJson(data as Map<String, dynamic>))
          .toList();

      Alert? found = allAlerts.firstWhere(
        (a) => a.id == widget.alertId,
        orElse: () => allAlerts.firstWhere(
          (a) => a.shiftId == widget.shiftId,
          orElse: () => throw Exception('Alert not found'),
        ),
      );

      setState(() {
        _alert = found;
        _acknowledged = found.isAcknowledged;
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load alert details.';
      });
      print('❌ AlertDetailScreen: Failed to load alert: $e');
    }
  }

  Future<void> _acknowledgeAlert() async {
    if (_alert == null || _isAcknowledging) return;
    HapticFeedback.lightImpact();

    setState(() => _isAcknowledging = true);

    try {
      await _shiftService.acknowledgeAlert(
        shiftId: _alert!.shiftId,
        alertType: _alert!.type.alertResponseApiValue,
      );

      await _notificationService.sendAlertResponseNotification(
        shiftId: _alert!.shiftId,
        alertType: _alert!.typeDisplayName,
        response: 'ACKNOWLEDGED',
        trainNumber: _alert!.shift?.trainNumber,
      );

      setState(() {
        _acknowledged = true;
        _isAcknowledging = false;
        _alert = _alert!.copyWith(
          status: AlertStatus.ACKNOWLEDGED,
          acknowledgedAt: DateTime.now(),
        );
      });

      HapticFeedback.mediumImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Alert acknowledged successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isAcknowledging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Failed to acknowledge: $e')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _viewShift() {
    if (_alert == null) return;
    final shiftRef = _alert!.shift;
    final dummyDuty = DutyAssignment(
      id: _alert!.shiftId,
      backendShiftId: _alert!.shiftId,
      trainNumber: shiftRef?.trainNumber ?? '',
      startTime: shiftRef?.signOnDateTime,
      createdAt: DateTime.now(),
      createdBy: 'system',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DutyDetailScreen(
          duty: dummyDuty,
          crewMembers: const [],
        ),
      ),
    );
  }

  void _viewAllAlerts() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AlertManagementScreen(),
      ),
    );
  }

  // ─── Color / Icon helpers ──────────────────────────────────────────────────

  Color _alertColor(AlertType type) {
    switch (type) {
      case AlertType.DUTY_8HR:
        return const Color(0xFFF59E0B);
      case AlertType.DUTY_10HR:
        return const Color(0xFFDC2626);
      case AlertType.DUTY_12HR:
        return const Color(0xFF7F1D1D);
      case AlertType.RELIEF_PLANNED:
        return const Color(0xFF7C3AED);
      case AlertType.SHIFT_COMPLETED:
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _alertIcon(AlertType type) {
    switch (type) {
      case AlertType.DUTY_8HR:
        return Icons.schedule_rounded;
      case AlertType.DUTY_10HR:
        return Icons.error_rounded;
      case AlertType.DUTY_12HR:
        return Icons.report_problem_rounded;
      case AlertType.RELIEF_PLANNED:
        return Icons.directions_run_rounded;
      case AlertType.SHIFT_COMPLETED:
        return Icons.check_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Alert Detail',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _fetchAlert,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton(isDark)
          : _errorMessage != null
              ? _buildError(isDark)
              : _buildContent(isDark),
    );
  }

  // ─── Loading skeleton ──────────────────────────────────────────────────────

  Widget _buildSkeleton(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _shimmer(isDark, height: 180, radius: 24),
          const SizedBox(height: 20),
          _shimmer(isDark, height: 200, radius: 20),
          const SizedBox(height: 16),
          _shimmer(isDark, height: 56, radius: 14),
          const SizedBox(height: 10),
          _shimmer(isDark, height: 56, radius: 14),
          const SizedBox(height: 10),
          _shimmer(isDark, height: 48, radius: 14),
        ],
      ),
    );
  }

  Widget _shimmer(bool isDark, {required double height, double radius = 12}) {
    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ─── Error state ───────────────────────────────────────────────────────────

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 56,
                color: AppTheme.errorRed.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Alert Not Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'This alert may have already been resolved or is no longer available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _viewAllAlerts,
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('View All Alerts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main content ──────────────────────────────────────────────────────────

  Widget _buildContent(bool isDark) {
    final alert = _alert!;
    final color = _alertColor(alert.type);
    final icon = _alertIcon(alert.type);
    final isPending = alert.isPending && !_acknowledged;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) => Opacity(
        opacity: _fadeAnimation.value,
        child: Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: child,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero banner ────────────────────────────────────────────────
            _buildHeroBanner(alert, color, icon, isDark),

            const SizedBox(height: 16),

            // ── Detail card ────────────────────────────────────────────────
            _buildDetailCard(alert, color, isDark),

            const SizedBox(height: 20),

            // ── Action buttons ─────────────────────────────────────────────
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildAcknowledgeButton(alert, color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildViewShiftButton(isDark),
                  ),
                ],
              ),
            ] else if (_acknowledged) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildAcknowledgedBadge(isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildViewShiftButton(isDark),
                  ),
                ],
              ),
            ] else ...[
              _buildViewShiftButton(isDark),
            ],

            const SizedBox(height: 12),

            // ── View All Alerts ────────────────────────────────────────────
            _buildViewAllButton(isDark),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(Alert alert, Color color, IconData icon, bool isDark) {
    final hasTrain = alert.shift?.trainNumber.isNotEmpty == true;
    final trainStr = hasTrain ? 'Train ${alert.shift!.trainNumber}' : '';
    final timeStr = _timeAgo(alert.sentAt);
    final subtitle = hasTrain ? '$trainStr • $timeStr' : timeStr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(isDark ? 0.3 : 0.12),
            color.withOpacity(isDark ? 0.15 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.35), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 18),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.typeDisplayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(Alert alert, Color color, bool isDark) {
    final statusColor = _acknowledged
        ? const Color(0xFF10B981)
        : (alert.isPending ? const Color(0xFFEA580C) : const Color(0xFF6B7280));
    
    final statusBgColor = statusColor.withOpacity(0.12);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF161B2E), const Color(0xFF1E253F)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'ALERT DETAIL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          // The message text (larger, beautiful typography)
          Text(
            alert.message,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          
          Divider(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            thickness: 1,
          ),
          const SizedBox(height: 16),

          // Metadata Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sent At
              Expanded(
                child: _buildMetaCell(
                  icon: Icons.schedule_rounded,
                  label: 'SENT AT',
                  value: _formatDateTime(alert.sentAt),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              // Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _acknowledged ? 'Acknowledged' : alert.statusDisplayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (alert.acknowledgedAt != null || _acknowledged) ...[
            const SizedBox(height: 20),
            Divider(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              thickness: 1,
            ),
            const SizedBox(height: 16),
            _buildMetaCell(
              icon: Icons.check_circle_outline_rounded,
              label: 'ACKNOWLEDGED AT',
              value: _formatDateTime(alert.acknowledgedAt ?? DateTime.now()),
              valueColor: const Color(0xFF10B981),
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaCell({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildAcknowledgeButton(Alert alert, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isAcknowledging ? null : _acknowledgeAlert,
        icon: _isAcknowledging
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_rounded, size: 20),
        label: Text(
          _isAcknowledging ? 'Acknowledging...' : 'Acknowledge',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.6),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildAcknowledgedBadge(bool isDark) {
    return Container(
      width: double.infinity,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
          SizedBox(width: 8),
          Text(
            'Acknowledged',
            style: TextStyle(
              color: Color(0xFF059669),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewShiftButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _viewShift,
        icon: const Icon(Icons.visibility_rounded, size: 20),
        label: const Text(
          'View Shift',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildViewAllButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _viewAllAlerts,
        icon: Icon(
          Icons.list_alt_rounded,
          size: 18,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        label: Text(
          'View All Alerts',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
