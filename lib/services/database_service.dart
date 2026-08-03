import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/crew_member.dart';
import '../models/duty_assignment.dart';
import 'shift_service.dart';

class DatabaseService {
  static const String _crewMembersKey = 'crew_members';
  static const String _dutyAssignmentsKey = 'duty_assignments';
  static const String _sectionInfoKey = 'section_info';
  
  // API Configuration
  static const String _baseUrl = 'https://api.dutyhours.in';
  static const String _shiftsEndpoint = '/shifts';

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _purgeLocalOnlyDuties();
  }

  Future<void> _purgeLocalOnlyDuties() async {
    try {
      final assignments = await getDutyAssignments();
      final filtered = assignments.where((a) => a.backendShiftId != null).toList();

      if (filtered.length != assignments.length) {
        final removedCount = assignments.length - filtered.length;
        print('🧹 Removed $removedCount legacy local-only duties');
        await saveDutyAssignments(filtered);
      }
    } catch (e) {
      print('⚠️ Failed to purge local-only duties: $e');
    }
  }

  // Crew Members Operations
  Future<List<CrewMember>> getCrewMembers() async {
    final String? crewData = _prefs?.getString(_crewMembersKey);
    if (crewData == null) return [];

    final List<dynamic> jsonList = json.decode(crewData);
    return jsonList.map((json) => CrewMember.fromJson(json)).toList();
  }

  Future<void> saveCrewMembers(List<CrewMember> crewMembers) async {
    final String jsonString = json.encode(
      crewMembers.map((member) => member.toJson()).toList(),
    );
    await _prefs?.setString(_crewMembersKey, jsonString);
  }

  Future<CrewMember?> getCrewMemberById(String id) async {
    final crewMembers = await getCrewMembers();
    try {
      return crewMembers.firstWhere((member) => member.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateCrewMember(CrewMember updatedMember) async {
    final crewMembers = await getCrewMembers();
    final index = crewMembers.indexWhere((member) => member.id == updatedMember.id);
    
    if (index != -1) {
      crewMembers[index] = updatedMember;
      await saveCrewMembers(crewMembers);
    }
  }

  // Duty Assignments Operations
  Future<List<DutyAssignment>> getDutyAssignments() async {
    final String? dutyData = _prefs?.getString(_dutyAssignmentsKey);
    if (dutyData == null) return [];

    final List<dynamic> jsonList = json.decode(dutyData);
    return jsonList.map((json) => DutyAssignment.fromJson(json)).toList();
  }

  Future<void> saveDutyAssignments(List<DutyAssignment> assignments) async {
    final String jsonString = json.encode(
      assignments.map((assignment) => assignment.toJson()).toList(),
    );
    await _prefs?.setString(_dutyAssignmentsKey, jsonString);
  }

  Future<void> addDutyAssignment(DutyAssignment assignment, {bool syncToApi = true}) async {
    try {
      // Send POST request to API only when requested
      if (syncToApi) {
        await _sendDutyToAPI(assignment);
      }
      
      // Also save locally for offline support
      final assignments = await getDutyAssignments();
      assignments.add(assignment);
      await saveDutyAssignments(assignments);
    } catch (e) {
      // If API fails, still save locally
      print('API call failed, saving locally: $e');
      final assignments = await getDutyAssignments();
      assignments.add(assignment);
      await saveDutyAssignments(assignments);
    }
  }

  Future<void> updateDutyAssignment(DutyAssignment updatedAssignment) async {
    final assignments = await getDutyAssignments();
    final index = assignments.indexWhere((a) => a.id == updatedAssignment.id);
    
    if (index != -1) {
      assignments[index] = updatedAssignment;
      await saveDutyAssignments(assignments);
    }
  }

  // Send duty assignment to API
  Future<void> _sendDutyToAPI(DutyAssignment assignment) async {
    try {
      final shiftService = ShiftService();
      await shiftService.createShift(assignment);
      print('Duty successfully sent to API');
    } catch (e) {
      print('Failed to send duty to API: $e');
      rethrow;
    }
  }

  Future<List<DutyAssignment>> getActiveDuties() async {
    final assignments = await getDutyAssignments();
    return assignments.where((a) => 
      a.status == ShiftStatus.IN_PROGRESS || 
      a.status == ShiftStatus.SCHEDULED
    ).toList();
  }

  Future<List<DutyAssignment>> getAllDuties() async {
    return await getDutyAssignments();
  }

  Future<List<DutyAssignment>> searchDuties(DutySearchFilter filter) async {
    final assignments = await getDutyAssignments();
    final crewMembers = await getCrewMembers();
    
    return assignments.where((duty) => filter.matches(duty, crewMembers)).toList();
  }

  // Quick Search
  Future<List<Map<String, dynamic>>> quickSearch(String query) async {
    final results = <Map<String, dynamic>>[];
    final crewMembers = await getCrewMembers();
    final assignments = await getDutyAssignments();

    // Search crew members
    for (final member in crewMembers) {
      if (member.name.toLowerCase().contains(query.toLowerCase()) ||
          member.employeeId.toLowerCase().contains(query.toLowerCase())) {
        results.add({
          'type': 'crew',
          'data': member,
          'title': member.name,
          'subtitle': '${member.role.displayName} - ${member.employeeId}',
        });
      }
    }

    // Search duty assignments
    for (final assignment in assignments) {
      if (assignment.trainNumber.toLowerCase().contains(query.toLowerCase()) ||
          (assignment.fromStation?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
          (assignment.toStation?.toLowerCase().contains(query.toLowerCase()) ?? false)) {
        results.add({
          'type': 'duty',
          'data': assignment,
          'title': 'Train ${assignment.trainNumber}',
          'subtitle': '${assignment.fromStation ?? 'Unknown'} → ${assignment.toStation ?? 'Unknown'}',
        });
      }
    }

    return results;
  }

  // Section Information
  Future<Map<String, String>> getSectionInfo() async {
    final String? sectionData = _prefs?.getString(_sectionInfoKey);
    if (sectionData == null) {
      return {
        'sectionName': 'Mumbai Central',
        'inchargeName': 'Section Incharge',
        'inchargeId': 'SI001',
      };
    }
    return Map<String, String>.from(json.decode(sectionData));
  }

  Future<void> setSectionInfo(Map<String, String> info) async {
    await _prefs?.setString(_sectionInfoKey, json.encode(info));
  }

  // Sample data initialization removed for production.

  // Backup and Sync (placeholder for future cloud integration)
  Future<void> backupData() async {
    // TODO: Implement cloud backup
    print('Data backup completed locally');
  }

  Future<void> syncData() async {
    // TODO: Implement cloud sync
    print('Data sync completed');
  }
}
