import 'package:flutter/material.dart';
import '../models/duty_assignment.dart';
import '../models/crew_member.dart';
import '../screens/duty_detail_screen.dart';
import '../theme/app_theme.dart';

class QuickSearchBar extends StatefulWidget {
  final List<DutyAssignment> activeDuties;
  final List<CrewMember> crewMembers;
  final bool isDarkMode;
  final VoidCallback onRefresh;

  const QuickSearchBar({
    super.key,
    required this.activeDuties,
    required this.crewMembers,
    required this.isDarkMode,
    required this.onRefresh,
  });

  @override
  State<QuickSearchBar> createState() => _QuickSearchBarState();
}

class _QuickSearchBarState extends State<QuickSearchBar> {
  bool _isSearching = false;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  List<DutyAssignment> _filteredDuties = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _unfocusSearch() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              widget.isDarkMode
                  ? [
                    AppTheme.cardBackground,
                    AppTheme.cardBackground.withOpacity(0.8),
                  ]
                  : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              widget.isDarkMode
                  ? Colors.blue.shade700.withOpacity(0.4)
                  : Colors.blue.shade300.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                widget.isDarkMode
                    ? Colors.black26
                    : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: AppTheme.accentOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Search',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      widget.isDarkMode
                          ? AppTheme.borderColor
                          : AppTheme.lightBorderColor,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: false,
                onTapOutside: (_) => _unfocusSearch(),
                onChanged: (query) {
                  setState(() {
                    _isSearching = query.isNotEmpty;
                    if (query.isEmpty) {
                      _filteredDuties = [];
                    } else {
                      _filteredDuties =
                          widget.activeDuties.where((duty) {
                            final guardName =
                                duty.trainManager?.name ?? 'Guard';
                            final pilotName = duty.locoPilot?.name ?? 'Pilot';

                            return duty.trainNumber.toLowerCase().contains(
                                  query.toLowerCase(),
                                ) ||
                                guardName.toLowerCase().contains(
                                  query.toLowerCase(),
                                ) ||
                                pilotName.toLowerCase().contains(
                                  query.toLowerCase(),
                                ) ||
                                (duty.fromStation?.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ) ??
                                    false) ||
                                (duty.toStation?.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ) ??
                                    false);
                          }).toList();
                    }
                  });
                },
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search crew members, trains, or duties...',
                  hintStyle: TextStyle(
                    color:
                        widget.isDarkMode
                            ? AppTheme.textSecondary
                            : Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color:
                        widget.isDarkMode
                            ? AppTheme.textSecondary
                            : Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            if (_isSearching && _filteredDuties.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color:
                      widget.isDarkMode ? AppTheme.surfaceColor : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        widget.isDarkMode
                            ? AppTheme.borderColor
                            : AppTheme.lightBorderColor,
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredDuties.length,
                  itemBuilder: (context, index) {
                    final duty = _filteredDuties[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color:
                            widget.isDarkMode
                                ? AppTheme.cardBackground
                                : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: Text(
                          'Train ${duty.trainNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${duty.trainManager?.name ?? 'Guard'} • ${duty.locoPilot?.name ?? 'Pilot'}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            duty.status.toString().split('.').last,
                            style: const TextStyle(
                              color: AppTheme.successGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        onTap: () {
                          _unfocusSearch();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => DutyDetailScreen(
                                    duty: duty,
                                    crewMembers: widget.crewMembers,
                                  ),
                            ),
                          ).then((_) {
                            widget.onRefresh();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
