// lib/screens/admin/access_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:convert'; // For Base64 encoding
import 'package:universal_html/html.dart' as html;
import '../../services/auth_service.dart';
import '../../theme/theme.dart'; // Import theme
import 'package:go_router/go_router.dart'; // For logout redirect

// Simple model for Log Entry for easier handling and type safety
class LogEntry {
  final String id;
  final String timestamp; // Already formatted string
  final String username;
  final String roomName;
  final String roomId;
  final bool accessGranted;
  final String faceResult;
  final String? failureReason;
  final double speakerScore; // Store as double (0.0 to 1.0)
  final double transcriptionScore; // Store as double (0.0 to 1.0)
  final bool isGenuineAudio;
  final String companyName; // Add company name for multi-tenancy

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.username,
    required this.roomName,
    required this.roomId,
    required this.accessGranted,
    required this.faceResult,
    this.failureReason,
    required this.speakerScore,
    required this.transcriptionScore,
    required this.isGenuineAudio,
    required this.companyName, // New field
  });

  // Factory constructor to parse JSON and format data
  factory LogEntry.fromJson(Map<dynamic, dynamic> json) {
    // Helper to parse double safely from various types
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper to format date string or return placeholder
    String formatDate(String? dateString) {
      if (dateString == null) return 'N/A';
      try {
        // Use toLocal() for user's timezone if appropriate
        final dateTime = DateTime.parse(dateString).toLocal();
        // Consistent format including seconds
        return DateFormat.yMd().add_Hms().format(dateTime);
      } catch (e) {
        print("Error parsing date in LogEntry: $dateString - $e");
        return dateString; // Return raw string if parsing fails
      }
    }

    return LogEntry(
      id: json['id']?.toString() ?? 'N/A',
      timestamp: formatDate(json['timestamp']?.toString()),
      username: json['username']?.toString() ?? 'Unknown',
      roomName: json['room_name']?.toString() ?? 'Unknown Room',
      roomId: json['room_id']?.toString() ?? 'N/A',
      accessGranted: json['access_granted'] == true,
      faceResult: json['face_spoofing_result']?.toString() ?? 'N/A',
      failureReason: json['failure_reason']?.toString(),
      // Ensure scores are parsed correctly
      speakerScore: parseDouble(json['speaker_similarity_score']),
      transcriptionScore: parseDouble(json['transcription_score']),
      // Ensure deepfake result is parsed correctly (assuming 1=genuine, 0=deepfake)
      isGenuineAudio: json['audio_deepfake_result'] == 1,
      // Get company name from the log entry (or use a default if not present)
      companyName: json['company_name']?.toString() ?? 'Unknown Company',
    );
  }

  // Convert log entry to a map for CSV export
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Timestamp': timestamp,
      'Username': username,
      'Room Name': roomName,
      'Room ID': roomId,
      'Access Granted': accessGranted ? 'Yes' : 'No',
      'Face Check': faceResult,
      'Failure Reason': failureReason ?? '',
      'Speaker Score (%)': (speakerScore * 100).toStringAsFixed(1),
      'Transcription Score (%)': (transcriptionScore * 100).toStringAsFixed(1),
      'Audio Type': isGenuineAudio ? 'Genuine' : 'Deepfake',
      'Company': companyName,
    };
  }
}

class AccessLogsScreen extends StatefulWidget {
  const AccessLogsScreen({super.key});

  @override
  State<AccessLogsScreen> createState() => _AccessLogsScreenState();
}

class _AccessLogsScreenState extends State<AccessLogsScreen> {
  bool _isLoading = false;
  List<LogEntry> _logs = [];
  String? _errorMessage;

  // Filter variables
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedRoomId;
  String? _selectedUsername;
  bool? _selectedAccessStatus; // Nullable bool for 'All' state
  bool _filtersExpanded = false; // State for ExpansionPanel

  // Store unique values fetched for dropdowns
  List<String> _availableRoomIds = [];
  List<String> _availableUsernames = [];

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    // Wait for auth service init (cookie jar, csrf) before fetching
    authService.initializationComplete.then((_) {
      if (mounted) {
        _fetchLogs(); // Initial fetch without filters
      }
    }).catchError((e) {
      // Handle error during auth service initialization
      if (mounted) {
        setState(() {
          _errorMessage = "Error initializing session: $e. Cannot fetch logs.";
          _isLoading = false; // Ensure loading is off
        });
      }
    });
  }

  // Fetch logs from the backend, applying current filters
  Future<void> _fetchLogs({bool preserveFilters = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    // Ensure initialization is complete before making the call
    await authService.initializationComplete;

    try {
      // Build query parameters from state variables
      final Map<String, dynamic> queryParams = {};
      if (_startDate != null) queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(_startDate!);
      if (_endDate != null) queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
      if (_selectedRoomId != null) queryParams['room_id'] = _selectedRoomId;
      if (_selectedUsername != null) queryParams['username'] = _selectedUsername;
      if (_selectedAccessStatus != null) queryParams['access_status'] = _selectedAccessStatus.toString(); // 'true' or 'false'

      final response = await authService.dioInstance.get('admin/access-logs/', queryParameters: queryParams);

      if (response.statusCode == 200 && response.data is List) {
        if (mounted) {
          final rawLogs = response.data as List;
          setState(() {
            _logs = rawLogs.map((logJson) {
              // Add try-catch around parsing individual entries for robustness
              try {
                return LogEntry.fromJson(logJson);
              } catch (e) {
                print("Error parsing log entry: $logJson - $e");
                // Return a dummy/error entry or filter it out
                return null; // Will be filtered out below
              }
            }).whereType<LogEntry>().toList(); // Filter out any nulls from parsing errors

            // Update available filter options only when not preserving filters
            // or if they haven't been populated yet.
            if (!preserveFilters || _availableRoomIds.isEmpty) {
              _availableRoomIds = _getUniqueValues(_logs, (log) => log.roomId);
            }
            if (!preserveFilters || _availableUsernames.isEmpty) {
              _availableUsernames = _getUniqueValues(_logs, (log) => log.username);
            }
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Handle unauthorized access (e.g., session expired)
        print("AccessLogs: Unauthorized fetching logs. Logging out.");
        authService.logout();
        if (mounted) context.go('/login');
        return;
      } else {
        // Handle other non-200 statuses
        throw Exception('Failed to load logs: Status ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      print("Error fetching logs: $e");
      if (mounted) {
        // Check for Dio-specific unauthorized errors
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
          print("AccessLogs: Unauthorized fetching logs (DioEx). Logging out.");
          authService.logout();
          context.go('/login');
          return;
        }
        // Show generic error message
        setState(() {
          _errorMessage = 'Failed to load access logs. Please try again.';
        });
      }
    } finally {
      // Ensure loading indicator is turned off
      if (mounted) setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to get unique, non-empty, sorted string values from the log list
  List<String> _getUniqueValues(List<LogEntry> logs, String Function(LogEntry) getValue) {
    final values = logs.map(getValue)
                     .where((v) => v.isNotEmpty && v != 'N/A') // Filter out empty/placeholder values
                     .toSet(); // Use a Set for automatic uniqueness
    return values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())); // Sort case-insensitively
  }

  // Reset all filters and fetch all logs
  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedRoomId = null;
      _selectedUsername = null;
      _selectedAccessStatus = null; // Reset to 'All' (null)
      _filtersExpanded = false; // Collapse filters panel
    });
    _fetchLogs(preserveFilters: false); // Fetch all logs and regenerate filter options
  }

  // Export logs to CSV and download
  void _exportToCSV() {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No logs to export'),
          backgroundColor: BioAccessTheme.errorColor,
        ),
      );
      return;
    }

    try {
      // Get current timestamp for filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'access_logs_${timestamp}.csv';
      
      // Convert logs to list of maps for CSV
      final List<Map<String, dynamic>> logsData = _logs.map((log) => log.toMap()).toList();
      
      // Get headers from the first log entry
      final headers = logsData.first.keys.toList();
      
      // Create list of lists for CSV conversion
      final List<List<dynamic>> csvData = [
        headers, // Add headers as first row
        ...logsData.map((log) => log.values.toList()), // Add data rows
      ];
      
      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);
      
      // Create download link for browsers
      final bytes = utf8.encode(csvString);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create anchor element
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;
      
      // Add to document and click
      html.document.body!.children.add(anchor);
      anchor.click();
      
      // Clean up
      html.Url.revokeObjectUrl(url);
      
      // Remove the anchor element after a small delay
      Future.delayed(const Duration(milliseconds: 100), () {
        anchor.remove();
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs exported successfully'),
          backgroundColor: BioAccessTheme.successColor,
        ),
      );
    } catch (e) {
      print("Error exporting CSV: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export logs: ${e.toString()}'),
          backgroundColor: BioAccessTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get company name from auth service for display
    final companyName = Provider.of<AuthService>(context).companyData?['name'] ?? 'Your Company';
    
    // Responsive padding based on screen width
    final horizontalPadding = MediaQuery.of(context).size.width > 600 ? 40.0 : 20.0;

    return Padding(
      // Apply responsive padding
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Text with company name
          Text('Access Logs - $companyName', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Monitor and filter all access attempts', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),

          // Error Message Area (Themed)
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: BioAccessTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BioAccessTheme.errorColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: BioAccessTheme.errorColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: BioAccessTheme.errorColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Close button for the error message
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: BioAccessTheme.errorColor,
                    tooltip: 'Dismiss error',
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),
          ],

          // Filters Section (Collapsible Panel)
          ExpansionPanelList(
            elevation: 1, // Subtle elevation
            expandedHeaderPadding: EdgeInsets.zero, // No extra padding when expanded
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                _filtersExpanded = !isExpanded;
              }); // Toggle expanded state
            },
            children: [
              ExpansionPanel(
                headerBuilder: (BuildContext context, bool isExpanded) {
                  // Clickable header to toggle filters
                  return ListTile(
                    leading: Icon(Icons.filter_list_alt, color: BioAccessTheme.primaryBlue), // Use alt icon
                    title: Text('Filters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text(isExpanded ? 'Adjust filters below' : 'Click to show filters', style: Theme.of(context).textTheme.bodySmall),
                  );
                },
                body: _buildFiltersContent(), // Content of the filter panel
                isExpanded: _filtersExpanded, // Control visibility
                canTapOnHeader: true, // Allow tapping header to toggle
                backgroundColor: Theme.of(context).colorScheme.surface, // Use theme surface color
              ),
            ],
          ),
          const SizedBox(height: 24), // Spacing after filters

          // Log Count, Refresh Button, and Export Button Row
          Row(
            children: [
              // Display log count (consider adding total if pagination is implemented)
              Text(
                'Displaying ${_logs.length} log(s)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(), // Pushes buttons to the right
              
              // Export to CSV button
              OutlinedButton.icon(
                onPressed: _isLoading || _logs.isEmpty ? null : _exportToCSV,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export CSV'),
                // Style applied from theme
              ),
              const SizedBox(width: 8),
              
              // Refresh button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _fetchLogs(preserveFilters: true), // Refresh with current filters
                // Show progress indicator inside button when loading
                icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2,)) : const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                // Style applied from theme
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Logs List Area (Shows loading or the list)
          Expanded(
            child: _isLoading && _logs.isEmpty // Show loading indicator only when list is empty and loading
                ? const Center(child: CircularProgressIndicator())
                : _buildLogsList(), // Build the responsive list of logs
          ),

          // Optional Pagination Controls Placeholder
          // const SizedBox(height: 16),
          // _buildPagination(), // Add pagination controls widget if implemented
        ],
      ),
    );
  }

  // Widget containing the filter input fields (responsive layout)
  Widget _buildFiltersContent() {
    // Use LayoutBuilder to adjust layout based on width
    return LayoutBuilder(builder: (context, constraints) {
      bool isWide = constraints.maxWidth > 650; // Breakpoint for filter layout

      return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Padding inside the panel body
        child: Column(
          children: [
            // --- Date Pickers ---
            if (isWide) // Row layout for wider screens
              Row(children: [
                Expanded(child: _buildDatePicker(label: 'Start Date', selectedDate: _startDate, onDateSelected: (d) => setState(() => _startDate = d))),
                const SizedBox(width: 16),
                Expanded(child: _buildDatePicker(label: 'End Date', selectedDate: _endDate, onDateSelected: (d) => setState(() => _endDate = d))),
              ])
            else // Column layout for narrower screens
              Column(children: [
                _buildDatePicker(label: 'Start Date', selectedDate: _startDate, onDateSelected: (d) => setState(() => _startDate = d)),
                const SizedBox(height: 16),
                _buildDatePicker(label: 'End Date', selectedDate: _endDate, onDateSelected: (d) => setState(() => _endDate = d)),
              ]),
            const SizedBox(height: 16),

            // --- Room ID & Username Dropdowns ---
            if (isWide) // Row layout for wider screens
              Row(children: [
                Expanded(child: _buildStringDropdown(label: 'Room ID', value: _selectedRoomId, items: _availableRoomIds, onChanged: (v) => setState(() => _selectedRoomId = v))),
                const SizedBox(width: 16),
                Expanded(child: _buildStringDropdown(label: 'Username', value: _selectedUsername, items: _availableUsernames, onChanged: (v) => setState(() => _selectedUsername = v))),
              ])
            else // Column layout for narrower screens
              Column(children: [
                _buildStringDropdown(label: 'Room ID', value: _selectedRoomId, items: _availableRoomIds, onChanged: (v) => setState(() => _selectedRoomId = v)),
                const SizedBox(height: 16),
                _buildStringDropdown(label: 'Username', value: _selectedUsername, items: _availableUsernames, onChanged: (v) => setState(() => _selectedUsername = v)),
              ]),
            const SizedBox(height: 16),

            // --- Access Status Dropdown & Action Buttons ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
              children: [
                // Status Dropdown (takes more space on mobile)
                Expanded(
                  flex: isWide ? 1 : 3, // Adjust flex factor
                  child: _buildStatusDropdown(), // Use specific helper
                ),
                const SizedBox(width: 16),
                // Action Buttons (Wrap allows stacking if needed, though less likely here)
                Expanded(
                  flex: isWide ? 1 : 2, // Adjust flex factor
                  child: Wrap(
                    alignment: WrapAlignment.end, // Align buttons to the right
                    spacing: 8, // Horizontal spacing
                    runSpacing: 8, // Vertical spacing if they wrap
                    children: [
                      // Reset Button (smaller style)
                      OutlinedButton(
                        onPressed: _resetFilters,
                        child: const Text('Reset'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      ),
                      // Apply Button (standard style)
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _filtersExpanded = false); // Collapse panel on apply
                          _fetchLogs(preserveFilters: false); // Fetch with new filters, regenerate dropdown options
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Apply'),
                        // Style from theme
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // Helper for Date Picker Input Field (Themed)
  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected,
  }) {
    return InkWell( // Make the whole field tappable
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)), // Allow up to tomorrow
        );
        if (mounted && picked != null && picked != selectedDate) {
          onDateSelected(picked);
        }
      },
      child: InputDecorator(
        // Use theme's input decoration
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          selectedDate != null ? DateFormat.yMMMd().format(selectedDate) : 'Any Date',
          style: TextStyle(
            // Use theme text color, slightly greyed out if no date selected
            color: selectedDate != null ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey.shade600,
            fontSize: 16, // Ensure consistent font size
          ),
        ),
      ),
    );
  }

  // Helper for String Dropdown Input Field (Themed)
  Widget _buildStringDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    IconData? prefixIcon = Icons.arrow_drop_down_circle_outlined, // Example default icon
  }) {
    // Map string items to DropdownMenuItem<String>
    List<DropdownMenuItem<String>> dropdownItems = items.map((itemValue) {
      return DropdownMenuItem<String>(value: itemValue, child: Text(itemValue));
    }).toList();

    // Add 'All' option at the beginning
    dropdownItems.insert(0, DropdownMenuItem<String>(
      value: null, // Use null value for 'All'
      child: Text('All', style: TextStyle(color: Colors.grey.shade600)),
    ));

    // Ensure the current value exists in the items or is null
    String? currentValue = value;
    if (value != null && !items.contains(value)) {
      currentValue = null; // Default to 'All' if value is no longer valid
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      ),
      value: currentValue,
      isExpanded: true,
      items: dropdownItems,
      onChanged: onChanged,
    );
  }

  // Specific helper for the Boolean Access Status Dropdown (Themed)
  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<bool?>(
      decoration: const InputDecoration(
        labelText: 'Access Status',
        prefixIcon: Icon(Icons.toggle_on_outlined, size: 20),
      ),
      value: _selectedAccessStatus,
      // Define items directly for bool?
      items: const [
        DropdownMenuItem<bool?>(
          value: null, // Represents 'All'
          child: Text('All', style: TextStyle(color: Colors.grey)),
        ),
        DropdownMenuItem<bool?>(
          value: true,
          child: Text('Granted', style: TextStyle(color: BioAccessTheme.successColor)),
        ),
        DropdownMenuItem<bool?>(
          value: false,
          child: Text('Denied', style: TextStyle(color: BioAccessTheme.errorColor)),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedAccessStatus = value;
        });
      },
    );
  }

  // Build the Logs List using responsive cards
  Widget _buildLogsList() {
    if (_logs.isEmpty) {
      // Displayed when filters result in no logs
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No Logs Match Filters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Try adjusting or resetting the filters.', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextButton(onPressed: _resetFilters, child: const Text('Reset Filters')),
          ],
        ),
      );
    }

    // Use RefreshIndicator for pull-to-refresh functionality
    return RefreshIndicator(
      onRefresh: () => _fetchLogs(preserveFilters: true), // Refresh with current filters
      color: BioAccessTheme.primaryBlue, // Theme color for indicator
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16), // Padding at the bottom of the list
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return _buildLogCard(log); // Use helper to build each card
        }
      ),
    );
  }

  // Helper Widget to Build a Single Log Card (Themed and More Detailed)
  Widget _buildLogCard(LogEntry log) {
    final bool isGranted = log.accessGranted;
    final Color statusColor = isGranted ? BioAccessTheme.successColor : BioAccessTheme.errorColor;
    final Color statusBgColor = statusColor.withOpacity(0.1);

    return Card(
      // Use theme card style
      margin: const EdgeInsets.only(bottom: 12.0), // Consistent bottom margin
      clipBehavior: Clip.antiAlias, // Ensures inkwell ripple stays within bounds
      child: InkWell( // Make card tappable for details dialog
        onTap: () => _showLogDetailsDialog(log),
        borderRadius: BorderRadius.circular(12), // Match card's border radius
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: User, Room, Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Align items to top
                children: [
                  // Leading Icon (Status)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0, right: 12.0),
                    child: Icon(
                      isGranted ? Icons.check_circle_outline : Icons.highlight_off,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  // User and Room Info (Expanded)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          '${log.roomName} (${log.roomId})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Timestamp (Aligned Right)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      log.timestamp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)
                    ),
                  ),
                ],
              ),

              // Failure Reason (Conditional)
              if (!isGranted && log.failureReason != null && log.failureReason!.isNotEmpty) ...[
                const Divider(height: 16, thickness: 0.5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.failureReason!,
                        style: TextStyle(color: statusColor, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // Link to view details
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'View Details',
                  style: TextStyle(color: BioAccessTheme.lightBlue, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Show Log Details Dialog (Themed)
  void _showLogDetailsDialog(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Use theme defaults, customize if needed
        // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10), // Adjust padding
        title: Row( // Title with status icon
          children: [
            Icon(log.accessGranted ? Icons.check_circle : Icons.cancel, color: log.accessGranted ? BioAccessTheme.successColor : BioAccessTheme.errorColor),
            const SizedBox(width: 8),
            const Text('Access Log Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Fit content
            children: [
              _buildLogDetailItem('Status', log.accessGranted ? 'Granted' : 'Denied', color: log.accessGranted ? BioAccessTheme.successColor : BioAccessTheme.errorColor),
              _buildLogDetailItem('Timestamp', log.timestamp, icon: Icons.access_time),
              _buildLogDetailItem('Username', log.username, icon: Icons.person_outline),
              _buildLogDetailItem('Room', '${log.roomName} (${log.roomId})', icon: Icons.meeting_room_outlined),
              _buildLogDetailItem('Company', log.companyName, icon: Icons.business_outlined), // Add company field
              if (!log.accessGranted && log.failureReason != null && log.failureReason!.isNotEmpty)
                _buildLogDetailItem('Failure Reason', log.failureReason!, icon: Icons.warning_amber_outlined, color: BioAccessTheme.errorColor),

              const Divider(height: 24),
              Text('Biometric Verification', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              _buildLogDetailItem('Face Check', log.faceResult.toUpperCase(), icon: Icons.face_retouching_natural_outlined, color: log.faceResult.toLowerCase() == 'genuine' ? BioAccessTheme.successColor : (log.faceResult.toLowerCase() == 'not_attempted' || log.faceResult.toLowerCase() == 'timeout' ? Colors.orange.shade700 : BioAccessTheme.errorColor) ),
              _buildLogDetailItem('Speaker Match', '${(log.speakerScore * 100).toStringAsFixed(1)}% (>= 70%)', icon: Icons.graphic_eq, color: log.speakerScore >= 0.7 ? BioAccessTheme.successColor : BioAccessTheme.errorColor),
              _buildLogDetailItem('Transcription Match', '${(log.transcriptionScore * 100).toStringAsFixed(1)}% (>= 80%)', icon: Icons.spellcheck_outlined, color: log.transcriptionScore >= 0.8 ? BioAccessTheme.successColor : BioAccessTheme.errorColor),
              _buildLogDetailItem('Audio Type', log.isGenuineAudio ? 'GENUINE' : 'DEEPFAKE DETECTED', icon: log.isGenuineAudio ? Icons.volume_up_outlined : Icons.volume_off_outlined , color: log.isGenuineAudio ? BioAccessTheme.successColor : BioAccessTheme.errorColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
            // Style from theme
          ),
        ],
      ),
    );
  }

  // Helper for consistent detail items in dialog (Themed)
  Widget _buildLogDetailItem(String label, String value, {IconData? icon, Color? color}) {
    final labelStyle = TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13);
    final valueStyle = TextStyle(color: color ?? Theme.of(context).textTheme.bodyLarge?.color, fontSize: 15);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Increase vertical padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, size: 20, color: color ?? Colors.grey.shade600) else const SizedBox(width: 20),
          const SizedBox(width: 16), // Increase spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 3), // Small gap
                Text(value, style: valueStyle),
              ],
            )
          ),
        ],
      ),
    );
  }
}