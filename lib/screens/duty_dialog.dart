import 'dart:async';
import 'package:flutter/material.dart';
import '../models/crew_member.dart';
import '../models/duty_assignment.dart';
import '../models/staff.dart';
import '../services/database_service.dart';
import '../services/shift_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class CreateDutyDialog extends StatefulWidget {
  final List<CrewMember> crewMembers;
  final Map<String, String> sectionInfo;
  final VoidCallback onDutyCreated;

  const CreateDutyDialog({
    super.key,
    required this.crewMembers,
    required this.sectionInfo,
    required this.onDutyCreated,
  });

  @override
  State<CreateDutyDialog> createState() => _CreateDutyDialogState();
}

class _CreateDutyDialogState extends State<CreateDutyDialog> {
  final DatabaseService _dbService = DatabaseService();
  final ShiftService _shiftService = ShiftService();
  final NotificationService _notificationService = NotificationService();

  String _friendlyDutyCreationError(Object error) {
    var message = error.toString();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }

    if (message.contains('Staff already on duty')) {
      return 'Cannot create duty. Selected staff are already on duty. End their current duty or choose different staff.';
    }

    if (message.toLowerCase().contains('session expired')) {
      return 'Your session expired. Please login again and retry duty creation.';
    }

    return message;
  }
  
  // Controllers
  final TextEditingController locomotiveNoController = TextEditingController();
  final TextEditingController locoPilotNameController = TextEditingController();
  final TextEditingController locoPilotIdController = TextEditingController();
  final TextEditingController trainManagerNameController = TextEditingController();
  final TextEditingController trainManagerIdController = TextEditingController();
  final TextEditingController trainManagerPhoneController = TextEditingController();
  final TextEditingController trainNumberController = TextEditingController();
  final TextEditingController trainNameController = TextEditingController();
  final TextEditingController signOnStationController = TextEditingController();
  final TextEditingController sectionController = TextEditingController();
  final TextEditingController locoPilotPhoneController = TextEditingController();
  
  // Focus nodes to manage focus properly
  final FocusNode trainManagerPhoneFocus = FocusNode();
  final FocusNode locoPilotPhoneFocus = FocusNode();
  final FocusNode dummyFocus = FocusNode(); // Dummy focus node to redirect focus
  
  // Date/Time variables
  DateTime? selectedSignOnDateTime = DateTime.now();
  DateTime? selectedTrainArrivalDateTime;
  DateTime? selectedTODateTime;
  DateTime? selectedDepartureDateTime;
  
  // Form state
  String selectedDutyType = 'SP';
  bool lobbySignOn = false;
  bool _isDarkMode = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    locomotiveNoController.dispose();
    locoPilotNameController.dispose();
    locoPilotIdController.dispose();
    trainManagerNameController.dispose();
    trainManagerIdController.dispose();
    trainManagerPhoneController.dispose();
    trainNumberController.dispose();
    trainNameController.dispose();
    signOnStationController.dispose();
    sectionController.dispose();
    locoPilotPhoneController.dispose();
    trainManagerPhoneFocus.dispose();
    locoPilotPhoneFocus.dispose();
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
        onTap: () {
          FocusScope.of(context).unfocus();
        },
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
                      _buildTrainInfoSection(),
                      const SizedBox(height: 24),
                      _buildCrewInfoSection(),
                      const SizedBox(height: 24),
                      _buildScheduleSection(),
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
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Duty Assignment',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assign crew members to train duty',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Train Information', Icons.train_rounded),
        const SizedBox(height: 12),
        
        _buildTextField(
          controller: trainNumberController,
          label: 'Train Number *',
          hint: 'e.g., 12345',
          icon: Icons.confirmation_number,
        ),
        
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: trainNameController,
          label: 'Train Name',
          hint: 'e.g., Rajdhani Express (Optional)',
          icon: Icons.train_outlined,
        ),
        
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: locomotiveNoController,
          label: 'Locomotive No.',
          hint: 'e.g., WAP-7-30343',
          icon: Icons.precision_manufacturing_rounded,
        ),
        
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: signOnStationController,
          label: 'Sign On Station',
          hint: 'e.g., NDLS',
          icon: Icons.location_on,
        ),
        
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: sectionController,
          label: 'Section *',
          hint: 'e.g., Delhi-Mumbai',
          icon: Icons.route,
        ),
        
        const SizedBox(height: 16),
        
        _buildDutyTypeDropdown(),
        
        const SizedBox(height: 16),
        
        CheckboxListTile(
          title: const Text('Lobby Sign On'),
          value: lobbySignOn,
          onChanged: (value) {
            setState(() {
              lobbySignOn = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildCrewInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Loco Pilot Information', Icons.person_rounded),
        const SizedBox(height: 12),
        
        _buildTextField(
          controller: locoPilotNameController,
          label: 'Name of Loco Pilot *',
          hint: 'Enter full name',
          icon: Icons.person_rounded,
        ),
        
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: locoPilotIdController,
          label: 'ID of LP',
          hint: 'Employee ID',
          icon: Icons.badge_rounded,
        ),
        
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: locoPilotPhoneController,
          label: 'Phone Number of LP',
          hint: 'Enter 10-digit mobile number',
          icon: Icons.phone_rounded,
          focusNode: locoPilotPhoneFocus,
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionTitle('Train Manager Information', Icons.manage_accounts_rounded),
        const SizedBox(height: 12),
        
        _buildTextField(
          controller: trainManagerNameController,
          label: 'Name of TM *',
          hint: 'Enter full name',
          icon: Icons.manage_accounts_rounded,
        ),
        
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: trainManagerIdController,
          label: 'ID of TM',
          hint: 'Employee ID',
          icon: Icons.badge_outlined,
        ),
        
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: trainManagerPhoneController,
          label: 'Phone Number of TM',
          hint: 'Enter 10-digit mobile number',
          icon: Icons.phone_rounded,
          focusNode: trainManagerPhoneFocus,
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Schedule Information', Icons.schedule),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildDateTimeSelector(
                label: 'Sign On Date & Time *',
                selectedDateTime: selectedSignOnDateTime,
                onDateTimeChanged: (dateTime) {
                  setState(() {
                    selectedSignOnDateTime = dateTime;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateTimeSelector(
                label: 'Train Arrival Date & Time',
                selectedDateTime: selectedTrainArrivalDateTime,
                onDateTimeChanged: (dateTime) {
                  setState(() {
                    selectedTrainArrivalDateTime = dateTime;
                  });
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: _buildDateTimeSelector(
                label: 'Time of TO (Turn Out)',
                selectedDateTime: selectedTODateTime,
                onDateTimeChanged: (dateTime) {
                  setState(() {
                    selectedTODateTime = dateTime;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateTimeSelector(
                label: 'Departure Date & Time',
                selectedDateTime: selectedDepartureDateTime,
                onDateTimeChanged: (dateTime) {
                  setState(() {
                    selectedDepartureDateTime = dateTime;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode 
          ? AppTheme.surfaceColor.withOpacity(0.5) 
          : Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: _isDarkMode 
                    ? AppTheme.textSecondary 
                    : AppTheme.lightTextSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _isDarkMode 
                    ? AppTheme.textSecondary 
                    : AppTheme.lightTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createDuty,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCreating ? Colors.grey : AppTheme.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isCreating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Creating...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Create Duty',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _createDuty() async {
    if (_isCreating) return; // Prevent multiple submissions
    
    print('🔍 Validating duty creation form...');
    
    // Validate required fields
    final missingFields = <String>[];
    if (trainNumberController.text.trim().isEmpty) missingFields.add('Train Number');
    if (locomotiveNoController.text.trim().isEmpty) missingFields.add('Locomotive Number');
    if (signOnStationController.text.trim().isEmpty) missingFields.add('Sign On Station');
    if (sectionController.text.trim().isEmpty) missingFields.add('Section');
    if (locoPilotNameController.text.trim().isEmpty) missingFields.add('Loco Pilot Name');
    if (locoPilotIdController.text.trim().isEmpty) missingFields.add('Loco Pilot ID');
    if (trainManagerNameController.text.trim().isEmpty) missingFields.add('Train Manager Name');
    if (trainManagerIdController.text.trim().isEmpty) missingFields.add('Train Manager ID');
    
    if (missingFields.isNotEmpty) {
      print('❌ Validation failed. Missing fields: ${missingFields.join(', ')}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Missing required fields: ${missingFields.join(', ')}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    print('✅ Validation passed. Creating duty...');
    
    setState(() {
      _isCreating = true;
    });
    
    try {
      await _createDutyAssignment();
      
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Duty created successfully!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        
        widget.onDutyCreated();
      }
    } catch (e) {
      print('❌ Failed to create duty: $e');
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to create duty: ${e.toString()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
          child: Icon(
            icon,
            color: AppTheme.accentOrange,
            size: 16,
          ),
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
            border: Border.all(
              color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedDutyType,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.work_outline,
                color: AppTheme.accentOrange,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'SP', child: Text('SP')),
              DropdownMenuItem(value: 'WR', child: Text('WR')),
              DropdownMenuItem(value: 'LR', child: Text('LR')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedDutyType = value;
                });
              }
            },
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
    int maxLines = 1,
    FocusNode? focusNode,
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
            border: Border.all(
              color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
              ),
              prefixIcon: Icon(
                icon,
                color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelector({
    required String label,
    DateTime? selectedDateTime,
    required Function(DateTime) onDateTimeChanged,
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
            border: Border.all(
              color: _isDarkMode ? AppTheme.borderColor : AppTheme.lightBorderColor,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                FocusScope.of(context).unfocus();
                await Future.delayed(const Duration(milliseconds: 100));
                
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDateTime ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppTheme.accentOrange,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                
                if (pickedDate != null) {
                  final TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: selectedDateTime != null 
                        ? TimeOfDay.fromDateTime(selectedDateTime) 
                        : TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: AppTheme.accentOrange,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  
                  if (pickedTime != null) {
                    final combinedDateTime = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                    onDateTimeChanged(combinedDateTime);
                  }
                }
                FocusScope.of(context).unfocus();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      color: _isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedDateTime != null 
                            ? '${selectedDateTime.day.toString().padLeft(2, '0')}-${selectedDateTime.month.toString().padLeft(2, '0')}-${selectedDateTime.year} -- ${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}' 
                            : 'dd-mm-yyyy --:--',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selectedDateTime != null 
                              ? (_isDarkMode ? AppTheme.textPrimary : AppTheme.lightTextPrimary)
                              : (_isDarkMode ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                        ),
                        overflow: TextOverflow.ellipsis,
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







  Future<void> _createDutyAssignment() async {
    print('📝 Creating duty assignment with backend API integration...');
    try {
      // Generate unique ID for the duty
      final String dutyId = 'duty_${DateTime.now().millisecondsSinceEpoch}';
      
      // Get available crew members to assign as guard
      final availableGuards = widget.crewMembers.where((c) => 
        c.role == CrewRole.guard && c.status == CrewStatus.available).toList();
      
      // For now, assign the first available crew member
      String guardId = availableGuards.isNotEmpty ? availableGuards.first.id : 'default_guard';
      
      // Create the duty assignment with API-aligned structure
      final dutyAssignment = DutyAssignment(
        id: dutyId,
        trainNumber: trainNumberController.text.trim(),
        trainName: trainNameController.text.trim().isEmpty ? null : trainNameController.text.trim(),
        locomotiveNo: locomotiveNoController.text.trim(),
        signOnStation: signOnStationController.text.trim(),
        section: sectionController.text.trim(),
        dutyType: selectedDutyType,
        lobbySignOn: lobbySignOn,
        trainArrivalDate: selectedTrainArrivalDateTime,
        trainArrivalTime: selectedTrainArrivalDateTime,
        signOnTime: selectedSignOnDateTime,
        timeOfTO: selectedTODateTime,
        departureTime: selectedDepartureDateTime,
        locoPilot: CrewMemberInfo(
          employeeId: locoPilotIdController.text.trim(),
          name: locoPilotNameController.text.trim(),
          phone: locoPilotPhoneController.text.trim(),
        ),
        trainManager: CrewMemberInfo(
          employeeId: trainManagerIdController.text.trim(),
          name: trainManagerNameController.text.trim(),
          phone: trainManagerPhoneController.text.trim(),
        ),
        guardId: guardId,
        fromStation: 'Origin Station', // Legacy field for backward compatibility
        toStation: 'Destination Station', // Legacy field for backward compatibility
        status: ShiftStatus.SCHEDULED,
        createdAt: DateTime.now(),
        createdBy: widget.sectionInfo['inchargeId'] ?? 'SI001',
        notes: 'Created via mobile app',
      );
      
      print('✅ Duty assignment created with API structure:');
      print('  - Train Number: ${trainNumberController.text.trim()}');
      print('  - Section: ${sectionController.text.trim()}');
      print('  - Duty Type: $selectedDutyType');
      print('  - Sign On Station: ${signOnStationController.text.trim()}');
      
      // Create shift on backend first. If backend fails, do not create local duty.
      print('🚀 Creating shift on backend...');
      final backendResponse = await _shiftService.createShift(dutyAssignment);
      final backendShiftId = backendResponse['data']['id'];
      print('✅ Backend shift created with ID: $backendShiftId');
      
      // Update duty assignment with backend shift ID
      final finalDutyAssignment = dutyAssignment.copyWith(
        backendShiftId: backendShiftId,
      );
      
      // Add to local database only. Backend create was already attempted above.
      await _dbService.addDutyAssignment(finalDutyAssignment, syncToApi: false);
      
      // Start notification monitoring for the new duty
      await _notificationService.startDutyNotifications(finalDutyAssignment);
      
      // Update crew member status to onDuty
      if (availableGuards.isNotEmpty) {
        final updatedGuard = availableGuards.first.copyWith(
          status: CrewStatus.onDuty,
          currentDutyStart: selectedDepartureDateTime,
          currentTrainNumber: trainNumberController.text.trim(),
        );
        await _dbService.updateCrewMember(updatedGuard);
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New duty created for Train ${trainNumberController.text.trim()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: _isDarkMode ? AppTheme.cardBackground : AppTheme.lightCardBackground,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Failed to create duty: $e');
      final friendlyMessage = _friendlyDutyCreationError(e);
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error,
                  color: AppTheme.errorRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    friendlyMessage,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: _isDarkMode ? AppTheme.cardBackground : AppTheme.lightCardBackground,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      rethrow;
    }
  }

}
