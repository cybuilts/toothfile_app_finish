// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toothfile/device_service.dart';
import 'forward_dialog.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:touch_bar/touch_bar.dart';

class ReceivedFilesTab extends StatefulWidget {
  const ReceivedFilesTab({super.key});

  @override
  State<ReceivedFilesTab> createState() => _ReceivedFilesTabState();
}

class _ReceivedFilesTabState extends State<ReceivedFilesTab> {
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _receivedFiles = [];
  List<Map<String, dynamic>> _filteredFiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterFiles);
    _fetchReceivedFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTouchBar());
  }

  void _updateTouchBar() {
    TouchBarHelper.setDashboardTouchBar(
      extraItems: [
        TouchBarButton(label: 'Refresh', onClick: _fetchReceivedFiles),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isVisibleForCurrentDevice(Map<String, dynamic> file) {
    final targetId = (file['target_device_id'] ?? '').toString().trim();
    if (targetId.isEmpty) return true;
    final currentDeviceId = DeviceService.instance.currentDeviceId;
    if (currentDeviceId == null || currentDeviceId.isEmpty) {
      return false;
    }
    return targetId == currentDeviceId;
  }

  void _filterFiles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFiles = _receivedFiles.where((file) {
        final fileName = (file['file_name'] ?? '').toLowerCase();
        final message = (file['message'] ?? '').toLowerCase();
        final senderName = (file['profiles']?['name'] ?? '').toLowerCase();
        return fileName.contains(query) ||
            message.contains(query) ||
            senderName.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchReceivedFiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await Supabase.instance.client
          .from('shared_files')
          .select('*')
          .eq('receiver_id', userId)
          .order('created_at', ascending: false);

      final filesWithSenderInfo = <Map<String, dynamic>>[];
      final senderIds = <String>{};
      for (final file in response) {
        if (!_isVisibleForCurrentDevice(file)) continue;
        final senderId = file['sender_id']?.toString();
        if (senderId != null && senderId.isNotEmpty) senderIds.add(senderId);
        filesWithSenderInfo.add(Map<String, dynamic>.from(file));
      }

      final senderById = <String, Map<String, dynamic>>{};
      if (senderIds.isNotEmpty) {
        final senderProfiles = await Supabase.instance.client.rpc(
          'get_public_profiles',
          params: {'_ids': senderIds.toList()},
        );
        for (final profile in List<Map<String, dynamic>>.from(senderProfiles)) {
          final id = profile['id']?.toString();
          if (id != null && id.isNotEmpty) {
            senderById[id] = profile;
          }
        }
      }

      for (final file in filesWithSenderInfo) {
        final senderId = file['sender_id']?.toString();
        if (senderId != null && senderById.containsKey(senderId)) {
          file['profiles'] = senderById[senderId];
        }
      }

      if (!mounted) return;
      setState(() {
        _receivedFiles = filesWithSenderInfo;
        _filteredFiles = filesWithSenderInfo;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load received files: ${e.toString()}';
          _isLoading = false;
        });
      }
      print('Error fetching received files: $e');
    }
  }

  Future<void> _deleteFile(String fileId, String fileName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final bodyTextColor = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    final dangerIconBg = isDark
        ? const Color(0xFF3B1A1A)
        : const Color(0xFFFEE2E2);
    final confirm = await TouchBarHelper.showModalBottomSheetWithTouchBar<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      touchBarActions: [
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
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: dangerIconBg,
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
              'Delete File?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete "$fileName"? This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: bodyTextColor),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: bodyTextColor,
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
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('shared_files')
            .delete()
            .eq('id', fileId);

        setState(() {
          _receivedFiles.removeWhere((f) => f['id'] == fileId);
          _filteredFiles.removeWhere((f) => f['id'] == fileId);
        });

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
                      'File deleted successfully',
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
                      'Failed to delete file: $e',
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
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final mutedTextColor = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    final hintTextColor = isDark
        ? const Color(0xFF8FA2BF)
        : const Color(0xFF94A3B8);
    final errorBg = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEF2F2);
    final emptyBg = isDark ? const Color(0xFF1D2A3F) : const Color(0xFFF1F5F9);
    final headerIconBg = isDark
        ? const Color(0xFF1B3A2A)
        : const Color(0xFFDCFCE7);

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
                          color: headerIconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          color: Color(0xFF16A34A),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Received Files',
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
                          onPressed: _fetchReceivedFiles,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Files shared with you by other users',
                    style: TextStyle(fontSize: 14, color: mutedTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
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
                  decoration: InputDecoration(
                    hintText: 'Search files, senders, or messages...',
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
            const SizedBox(height: 20),

            // Files List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: errorBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFEF4444),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _filteredFiles.isEmpty
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
                              Icons.inbox_outlined,
                              size: 64,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No received files',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'No files match your search'
                                : 'Files shared with you will appear here',
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
                      itemCount: _filteredFiles.length,
                      itemBuilder: (context, index) {
                        final file = _filteredFiles[index];
                        return ReceivedFileCard(
                          file: file,
                          isMobile: isMobile,
                          onDelete: () => _deleteFile(
                            file['id'].toString(),
                            file['file_name'] ?? 'Unknown File',
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

class ReceivedFileCard extends StatefulWidget {
  final Map<String, dynamic> file;
  final bool isMobile;
  final VoidCallback onDelete;

  const ReceivedFileCard({
    super.key,
    required this.file,
    this.isMobile = false,
    required this.onDelete,
  });

  @override
  State<ReceivedFileCard> createState() => _ReceivedFileCardState();
}

class _ReceivedFileCardState extends State<ReceivedFileCard> {
  bool _downloading = false;

  Future<void> _downloadFile(String path, String fileName) async {
    try {
      setState(() => _downloading = true);
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        final url = await Supabase.instance.client.storage
            .from('dental-files')
            .createSignedUrl(path, 600);
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                      Icons.open_in_browser_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Downloading via browser',
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
      } else {
        final data = await Supabase.instance.client.storage
            .from('dental-files')
            .download(path);
        final prefs = await SharedPreferences.getInstance();
        final prefPath = prefs.getString('download_path');
        Directory targetDir;
        if (prefPath != null && prefPath.isNotEmpty) {
          targetDir = Directory(prefPath);
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
        } else {
          Directory? downloadsDir;
          try {
            downloadsDir = await getDownloadsDirectory();
          } catch (_) {}
          targetDir = downloadsDir ?? await getApplicationDocumentsDirectory();
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
        }
        final file = File('${targetDir.path}/$fileName');
        await file.writeAsBytes(data);
        // Do not auto-open file location
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
                  Expanded(
                    child: Text(
                      'File saved to: ${file.path}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
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
      }
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
                    'Download failed: $e',
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
    } finally {
      setState(() => _downloading = false);
    }
  }

  void _showAdvancedOptions(BuildContext context) {
    final file = widget.file;
    final customerName = file['customer_name'] ?? 'N/A';
    final selectedTeeth =
        (file['selected_teeth'] as List?)?.join(', ') ?? 'N/A';
    final toothColor = file['tooth_color'] ?? 'N/A';

    TouchBarHelper.showModalBottomSheetWithTouchBar(
      context: context,
      backgroundColor: Colors.transparent,
      touchBarActions: [
        TouchBarHelperAction(
          label: 'Done',
          action: () => Navigator.pop(context),
          isPrimary: true,
        ),
      ],
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
        final borderColor = isDark
            ? const Color(0xFF2B3A55)
            : const Color(0xFFE2E8F0);
        final titleColor = isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF020817);
        return Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.info_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow(
                  'Customer Name',
                  customerName,
                  Icons.person_rounded,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  'Selected Teeth',
                  selectedTeeth,
                  Icons.medical_services_rounded,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  'Tooth Color',
                  toothColor,
                  Icons.palette_rounded,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      context
          .findAncestorStateOfType<_ReceivedFilesTabState>()
          ?._updateTouchBar();
    });
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final labelColor = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    final valueColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final fileName = file['file_name'] ?? 'Unknown File';
    final message = file['message'] ?? '';
    final sender = file['profiles'] ?? {};
    final senderName = sender['name'] ?? 'Unknown Sender';
    final senderEmail = _emailOrMaskedId(sender);
    final senderRole = sender['role'] ?? sender['user_role'] ?? 'User';
    final createdAt = DateTime.parse(file['created_at']);
    final formattedDate =
        '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final mutedTextColor = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    final subtleIcon = isDark
        ? const Color(0xFF8FA2BF)
        : const Color(0xFF94A3B8);
    final actionCardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final deleteBg = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
    final messageBorder = isDark
        ? const Color(0xFF2E4365)
        : const Color(0xFFDBEAFE);
    final fileBorder = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final infoBarBg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final onlineBorder = isDark ? const Color(0xFF111827) : Colors.white;
    final roleChipBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final roleChipText = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF2563EB);

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
            // Header
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4B5563), Color(0xFF6B7280)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        child: Text(
                          senderName.isNotEmpty
                              ? senderName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: onlineBorder, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: roleChipBg,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              senderRole,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: roleChipText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: subtleIcon,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: actionCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send_rounded, size: 20, color: titleColor),
                    onPressed: () {
                      TouchBarHelper.showModalBottomSheetWithTouchBar(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        touchBarActions:
                            [], // No touchbar actions for this dialog
                        builder: (context) =>
                            ForwardDialog(fileRecord: widget.file),
                      ).then((_) {
                        context
                            .findAncestorStateOfType<_ReceivedFilesTabState>()
                            ?._updateTouchBar();
                      });
                    },
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: 'Forward File',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: deleteBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_rounded,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    onPressed: widget.onDelete,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete File',
                  ),
                ),
              ],
            ),

            if (message.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2563EB).withOpacity(isDark ? 0.16 : 0.05),
                      const Color(0xFF8B5CF6).withOpacity(isDark ? 0.16 : 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: messageBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.message_rounded,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // File Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(isDark ? 0.16 : 0.05),
                    const Color(0xFF6366F1).withOpacity(isDark ? 0.16 : 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: fileBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.insert_drive_file_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fileName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: titleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _downloading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  _downloadFile(file['file_path'], fileName),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.download_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Download',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Advanced Options
            InkWell(
              onTap: () => _showAdvancedOptions(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: infoBarBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'View Order Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emailOrMaskedId(Map<String, dynamic> profile) {
    final email = profile['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    final id = profile['id']?.toString() ?? '';
    if (id.length >= 4) return 'ID •••• ${id.substring(id.length - 4)}';
    return 'ID ••••';
  }
}
