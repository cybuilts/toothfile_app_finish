import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:touch_bar/touch_bar.dart';

class FileTrackerTab extends StatefulWidget {
  const FileTrackerTab({super.key});

  @override
  State<FileTrackerTab> createState() => _FileTrackerTabState();
}

class _FileTrackerTabState extends State<FileTrackerTab> {
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _sentFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All Status';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadSentFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTouchBar());
  }

  void _updateTouchBar() {
    TouchBarHelper.setDashboardTouchBar(
      extraItems: [
        TouchBarButton(label: 'Refresh', onClick: _loadSentFiles),
        TouchBarButton(
          label: 'Filter: $_selectedFilter',
          onClick: _showFilterOptions,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSentFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final filesData = await supabase
          .from('shared_files')
          .select(
            'id, file_name, file_size, file_type, created_at, receiver_id',
          )
          .eq('sender_id', user.id)
          .order('created_at', ascending: false);

      final receiverIds = filesData
          .map((f) => f['receiver_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> receiverProfiles = {};
      if (receiverIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, name, email')
            .inFilter('id', receiverIds);

        for (var profile in profiles) {
          receiverProfiles[profile['id']] = profile;
        }
      }

      for (var file in filesData) {
        final receiverId = file['receiver_id'];
        if (receiverId != null && receiverProfiles.containsKey(receiverId)) {
          file['receiver_name'] =
              receiverProfiles[receiverId]?['name'] ?? 'Unknown';
          file['receiver_email'] =
              receiverProfiles[receiverId]?['email'] ?? 'N/A';
        } else {
          file['receiver_name'] = 'Unknown';
          file['receiver_email'] = 'N/A';
        }

        try {
          final trackingData = await supabase
              .from('file_tracking')
              .select('event_type, created_at')
              .eq('shared_file_id', file['id'])
              .order('created_at', ascending: false);

          file['tracking_events'] = trackingData;
        } catch (e) {
          file['tracking_events'] = [];
        }
      }

      setState(() {
        _sentFiles = List<Map<String, dynamic>>.from(filesData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error loading files: $e',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            elevation: 4,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFileStatus(Map<String, dynamic> file) {
    final events = file['tracking_events'] as List<dynamic>?;
    if (events == null || events.isEmpty) return 'Sent';

    final eventTypes = events.map((e) => e['event_type']).toSet();

    if (eventTypes.contains('downloaded')) return 'Downloaded';
    if (eventTypes.contains('viewed')) return 'Viewed';
    return 'Sent';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  List<Map<String, dynamic>> _getFilteredFiles() {
    var filtered = _sentFiles;

    // Apply status filter
    if (_selectedFilter != 'All Status') {
      filtered = filtered.where((file) {
        return _getFileStatus(file) == _selectedFilter;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isEmpty) return filtered;

    return filtered.where((file) {
      final fileName = (file['file_name'] as String).toLowerCase();
      final receiverName =
          (file['receiver_name'] as String?)?.toLowerCase() ?? '';
      final receiverEmail =
          (file['receiver_email'] as String?)?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return fileName.contains(query) ||
          receiverName.contains(query) ||
          receiverEmail.contains(query);
    }).toList();
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
        final borderColor = isDark
            ? const Color(0xFF2B3A55)
            : const Color(0xFFE2E8F0);
        final titleColor = isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF020817);
        final unselectedText = isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF0F172A);
        final unselectedIconBg = isDark
            ? const Color(0xFF1D2A3F)
            : const Color(0xFFF1F5F9);
        final unselectedIcon = isDark
            ? const Color(0xFFA8B3C7)
            : const Color(0xFF64748B);
        final selectedBg = isDark
            ? const Color(0xFF1B3A2A)
            : const Color(0xFFDCFCE7);
        final selectedBorder = isDark
            ? const Color(0xFF2F7C4A)
            : const Color(0xFF86EFAC);
        final selectedText = isDark
            ? const Color(0xFF86EFAC)
            : const Color(0xFF14532D);
        return Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Filter by Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...['All Status', 'Sent', 'Viewed', 'Downloaded'].map((status) {
                    final isSelected = _selectedFilter == status;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedFilter = status;
                            _updateTouchBar();
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? selectedBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? selectedBorder
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF16A34A)
                                      : unselectedIconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  status == 'Downloaded'
                                      ? Icons.download_done_rounded
                                      : status == 'Viewed'
                                      ? Icons.visibility_rounded
                                      : status == 'Sent'
                                      ? Icons.send_rounded
                                      : Icons.filter_list_rounded,
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : unselectedIcon,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? selectedText
                                        : unselectedText,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF16A34A),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _updateTouchBar();
    });
  }

  Future<void> _deleteFile(String fileId, String fileName) async {
    final confirm =
        await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) {
            TouchBarHelper.setPopupTouchBar(
              context: context,
              actions: [
                TouchBarHelperAction(
                  label: 'Cancel',
                  action: () => Navigator.pop(context, false),
                ),
                TouchBarHelperAction(
                  label: 'Delete',
                  action: () => Navigator.pop(context, true),
                  isDestructive: true,
                ),
              ],
            );
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
            final borderColor = isDark
                ? const Color(0xFF2B3A55)
                : const Color(0xFFE2E8F0);
            final titleColor = isDark
                ? const Color(0xFFE5E7EB)
                : const Color(0xFF020817);
            final mutedTextColor = isDark
                ? const Color(0xFFA8B3C7)
                : const Color(0xFF64748B);
            final dangerSoft = isDark
                ? const Color(0xFF3B1A1A)
                : const Color(0xFFFEE2E2);
            return Container(
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: borderColor, width: 1)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dangerSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Delete File Record?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to delete the tracking record for "$fileName"?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: mutedTextColor),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: mutedTextColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ).then((_) {
          _updateTouchBar();
        });

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('shared_files')
            .delete()
            .eq('id', fileId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'File record deleted successfully',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              elevation: 4,
            ),
          );
        }
        await _loadSentFiles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error deleting file: $e',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              elevation: 4,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFiles = _getFilteredFiles();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark
        ? const Color(0xFF0B1220)
        : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final panelColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final mutedTextColor = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    final hintTextColor = isDark
        ? const Color(0xFF8FA2BF)
        : const Color(0xFF94A3B8);
    final chipBg = isDark ? const Color(0xFF1B3A2A) : const Color(0xFFDCFCE7);
    final chipText = isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A);
    final emptyBg = isDark ? const Color(0xFF1D2A3F) : const Color(0xFFF1F5F9);
    final trackerIconBg = isDark
        ? const Color(0xFF1B3A2A)
        : const Color(0xFFDCFCE7);
    final onlineBorder = isDark ? const Color(0xFF111827) : Colors.white;
    final deleteBg = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
    final statusTimeBg = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFF1F5F9);
    final progressTrack = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final downloadedBg = isDark
        ? const Color(0xFF1B3A2A)
        : const Color(0xFFDCFCE7);
    final viewedBg = isDark
        ? const Color(0xFF3B2F1A)
        : const Color(0xFFFEF3C7);
    final sentBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    final downloadedText = isDark
        ? const Color(0xFF86EFAC)
        : const Color(0xFF16A34A);
    final viewedText = isDark
        ? const Color(0xFFFCD34D)
        : const Color(0xFFF59E0B);
    final sentText = isDark ? const Color(0xFFBFDBFE) : const Color(0xFF2563EB);

    return Container(
      color: pageColor,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: trackerIconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.track_changes_rounded,
                          color: Color(0xFF16A34A),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'File Tracker',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 24,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: mutedTextColor,
                            size: 20,
                          ),
                          onPressed: _loadSentFiles,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track the status of files you\'ve sent to others',
                    style: TextStyle(fontSize: 14, color: mutedTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search and Filter Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search files, recipients...',
                          hintStyle: TextStyle(color: hintTextColor),
                          prefixIcon: Icon(
                            Icons.search,
                            color: hintTextColor,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color: mutedTextColor,
                        size: 22,
                      ),
                      onPressed: _showFilterOptions,
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedFilter != 'All Status')
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  12,
                  isMobile ? 16 : 24,
                  0,
                ),
                child: Chip(
                  label: Text(_selectedFilter),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _selectedFilter = 'All Status';
                      _updateTouchBar();
                    });
                  },
                  backgroundColor: chipBg,
                  labelStyle: TextStyle(
                    color: chipText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // File Cards
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: emptyBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_open_rounded,
                              size: 64,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No files sent yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Files you send will be tracked here',
                            style: TextStyle(
                              fontSize: 14,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 24,
                        0,
                        isMobile ? 16 : 24,
                        isMobile ? 16 : 24,
                      ),
                      itemCount: filteredFiles.length,
                      itemBuilder: (context, index) {
                        final file = filteredFiles[index];
                        final status = _getFileStatus(file);
                        final receiverName = file['receiver_name'] ?? 'Unknown';
                        final receiverEmail = file['receiver_email'] ?? 'N/A';
                        final initials =
                            receiverName.isNotEmpty && receiverName != 'Unknown'
                            ? receiverName[0].toUpperCase()
                            : 'U';
                        final createdAt = DateTime.parse(file['created_at']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // File Info Row
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF8B5CF6),
                                            Color(0xFF6366F1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF8B5CF6,
                                            ).withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.insert_drive_file_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file['file_name'],
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: titleColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatFileSize(file['file_size']),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: mutedTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status == 'Downloaded'
                                            ? downloadedBg
                                            : status == 'Viewed'
                                            ? viewedBg
                                            : sentBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: status == 'Downloaded'
                                              ? downloadedText
                                              : status == 'Viewed'
                                              ? viewedText
                                              : sentText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: deleteBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.delete_rounded,
                                          size: 18,
                                          color: Color(0xFFEF4444),
                                        ),
                                        onPressed: () => _deleteFile(
                                          file['id'],
                                          file['file_name'],
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Receiver Info Row
                                Row(
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF4B5563),
                                                Color(0xFF6B7280),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.transparent,
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF22C55E),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: onlineBorder,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            receiverName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: titleColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            receiverEmail,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: mutedTextColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusTimeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 12,
                                            color: mutedTextColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeago.format(createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: mutedTextColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Progress Row
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: panelColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    children: [
                                      // Progress Bar
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: progressTrack,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor: status == 'Downloaded'
                                                ? 1.0
                                                : status == 'Viewed'
                                                ? 0.66
                                                : 0.33,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF16A34A),
                                                    Color(0xFF22C55E),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF16A34A,
                                                    ).withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Labels
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 16,
                                            color: Color(0xFF16A34A),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Sent',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.visibility_rounded,
                                            size: 16,
                                            color:
                                                status == 'Viewed' ||
                                                    status == 'Downloaded'
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Viewed',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  status == 'Viewed' ||
                                                      status == 'Downloaded'
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.download_rounded,
                                            size: 16,
                                            color: status == 'Downloaded'
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Downloaded',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: status == 'Downloaded'
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
