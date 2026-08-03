import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/duty_assignment.dart';
import '../services/shift_service.dart';
import '../theme/app_theme.dart';

class EditDutyDialog extends StatefulWidget {
  final DutyAssignment duty;
  final Map<String, dynamic>? backendShiftData;
  final VoidCallback onDutyUpdated;

  const EditDutyDialog({
    super.key,
    required this.duty,
    this.backendShiftData,
    required this.onDutyUpdated,
  });

  @override
  State<EditDutyDialog> createState() => _EditDutyDialogState();
}

class _EditDutyDialogState extends State<EditDutyDialog> {
  final ShiftService _shiftService = ShiftService();
  
  // Controllers
  late TextEditingController signOffStationController;
  late TextEditingController sectionController;
  late TextEditingController reliefReasonController;
  
  final FocusNode dummyFocus = FocusNode(); 
  
  // Date/Time variables
  DateTime? selectedTOTime;
  DateTime? selectedDepartureTime;
  DateTime? selectedSignOffTime;
  
  // Form state
  late String selectedDutyType;
  late ShiftStatus selectedStatus;
  late bool reliefPlanned;
  
  bool _isDarkMode = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final shift = widget.backendShiftData;
    final duty = widget.duty;
    
    signOffStationController = TextEditingController(text: shift?['signOffStation'] ?? duty.toStation ?? '');
    sectionController = TextEditingController(text: shift?['section'] ?? duty.section ?? '');
    reliefReasonController = TextEditingController(text: shift?['reliefReason'] ?? '');
    
    selectedDutyType = shift?['dutyType'] ?? duty.dutyType ?? 'SP';
    
    final statusStr = shift?['status'] ?? duty.status.toString().split('.').last;
    selectedStatus = ShiftStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => ShiftStatus.IN_PROGRESS,
    );
    
    reliefPlanned = shift?['reliefPlanned'] ?? false;
    
    selectedTOTime = _parseTime(shift?['timeOfTO']) ?? duty.timeOfTO;
    selectedDepartureTime = _parseTime(shift?['departureDateTime']) ?? duty.departureTime;
    selectedSignOffTime = _parseTime(shift?['signOffDateTime']) ?? duty.endTime;
  }
  
  DateTime? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    try {
      return DateTime.parse(timeStr).toLocal();
    } catch (e) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    signOffStationController.dispose();
    sectionController.dispose();
    reliefReasonController.dispose();
    dummyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _isDarkMode ? AppTheme.cardBackground : AppTheme.lightCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.98,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Shift Properties', Icons.edit_note_rounded),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: sectionController,
                        label: 'Section',
                        hint: 'e.g., Delhi-Mumbai',
                        icon: Icons.route,
                      ),
                      const SizedBox(height: 16),
                      _buildDutyTypeDropdown(),
                      const SizedBox(height: 16),
                      _buildStatusDropdown(),
                      
                      const SizedBox(height: 24),
                      _buildSectionTitle('Relief Information', Icons.swap_horiz_rounded),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: Text('Relief Planned', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                            fontWeight: FontWeight.w500)),
                        value: reliefPlanned,
                        activeColor: AppTheme.accentOrange,
                        onChanged: (value) {
                          setState(() {
                            reliefPlanned = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (reliefPlanned) ...[
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: reliefReasonController,
                          label: 'Relief Reason',
                          hint: 'Enter reason for relief',
                          icon: Icons.comment_rounded,
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      _buildSectionTitle('Schedule Updates', Icons.schedule_rounded),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeSelector(
                              label: 'Time of TO',
                              selectedTime: selectedTOTime,
                              onTimeChanged: (time) {
                                setState(() => selectedTOTime = time);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimeSelector(
                              label: 'Departure Time',
                              selectedTime: selectedDepartureTime,
                              onTimeChanged: (time) {
                                setState(() => selectedDepartureTime = time);
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: signOffStationController,
                        label: 'Sign Off Station',
                        hint: 'e.g., BCT',
                        icon: Icons.location_on,
                      ),
                      const SizedBox(height: 16),
                      _buildTimeSelector(
                        label: 'Sign Off Time',
                        selectedTime: selectedSignOffTime,
                        onTimeChanged: (time) {
                          setState(() => selectedSignOffTime = time);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentOrange,
            AppTheme.accentOrange.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Shift Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Train ${widget.duty.trainNumber}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppTheme.accentOrange, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor),
          ),
          child: TextField(
            controller: controller,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
              prefixIcon: Icon(icon, color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDutyTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duty Type',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedDutyType,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.work_outline, color: AppTheme.accentOrange, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'SP', child: Text('SP')),
              DropdownMenuItem(value: 'WR', child: Text('WR')),
              DropdownMenuItem(value: 'LR', child: Text('LR')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => selectedDutyType = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor),
          ),
          child: DropdownButtonFormField<ShiftStatus>(
            value: selectedStatus,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.info_outline, color: AppTheme.accentOrange, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: ShiftStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status.toString().split('.').last),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => selectedStatus = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector({
    required String label,
    DateTime? selectedTime,
    required Function(DateTime) onTimeChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                FocusScope.of(context).unfocus();
                dummyFocus.requestFocus();
                await Future.delayed(const Duration(milliseconds: 150));
                
                final now = DateTime.now();
                
                // First ask for date
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedTime ?? now,
                  firstDate: now.subtract(const Duration(days: 30)),
                  lastDate: now.add(const Duration(days: 30)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppTheme.accentOrange),
                    ),
                    child: child!,
                  ),
                );
                
                if (pickedDate != null && mounted) {
                  // Then ask for time
                  final TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(selectedTime ?? now),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppTheme.accentOrange),
                      ),
                      child: child!,
                    ),
                  );
                  
                  if (pickedTime != null) {
                    final newDateTime = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                    onTimeChanged(newDateTime);
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedTime != null 
                            ? '${selectedTime.day.toString().padLeft(2, '0')}/${selectedTime.month.toString().padLeft(2, '0')} ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
                            : 'Select time',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selectedTime != null)
                      GestureDetector(
                        onTap: () {
                          // Allow clearing the time
                          setState(() {
                            if (label == 'Time of TO') selectedTOTime = null;
                            if (label == 'Departure Time') selectedDepartureTime = null;
                            if (label == 'Sign Off Time') selectedSignOffTime = null;
                          });
                        },
                        child: Icon(
                          Icons.clear_rounded,
                          color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? AppTheme.surfaceColor.withOpacity(0.5) : Colors.grey.shade50,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveShift,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaving ? Colors.grey : AppTheme.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveShift() async {
    final shiftId = widget.duty.backendShiftId;
    if (shiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit locally-created legacy shifts.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final updates = <String, dynamic>{
        'section': sectionController.text.trim(),
        'dutyType': selectedDutyType,
        'status': selectedStatus.toString().split('.').last,
        'reliefPlanned': reliefPlanned,
      };

      if (signOffStationController.text.trim().isNotEmpty) {
        updates['signOffStation'] = signOffStationController.text.trim();
      }
      
      if (reliefPlanned && reliefReasonController.text.trim().isNotEmpty) {
        updates['reliefReason'] = reliefReasonController.text.trim();
      }

      String toUtcIso(DateTime dt) => dt.toUtc().toIso8601String();

      if (selectedTOTime != null) updates['timeOfTO'] = toUtcIso(selectedTOTime!);
      if (selectedDepartureTime != null) updates['departureDateTime'] = toUtcIso(selectedDepartureTime!);
      if (selectedSignOffTime != null) updates['signOffDateTime'] = toUtcIso(selectedSignOffTime!);

      print('📤 Sending PATCH update: ${json.encode(updates)}');
      await _shiftService.updateShift(shiftId, updates);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update shift: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
