import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:touch_bar/touch_bar.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  List<Map<String, dynamic>> _connectionRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConnectionRequests();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTouchBar());
  }

  void _updateTouchBar() {
    TouchBarHelper.setDashboardTouchBar(
      extraItems: [
        TouchBarButton(label: 'Refresh', onClick: _loadConnectionRequests),
      ],
    );
  }

  Future<void> _loadConnectionRequests() async {
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

      final requestsData = await supabase
          .from('connection_requests')
          .select('*')
          .eq('receiver_id', user.id)
          .neq('status', 'accepted')
          .order('created_at', ascending: false);

      final senderIds = requestsData
          .map((request) => request['sender_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final sendersById = <String, Map<String, dynamic>>{};
      if (senderIds.isNotEmpty) {
        final senderProfiles = await supabase.rpc(
          'get_public_profiles',
          params: {'_ids': senderIds},
        );
        for (final profile in List<Map<String, dynamic>>.from(senderProfiles)) {
          final id = profile['id']?.toString();
          if (id != null && id.isNotEmpty) {
            sendersById[id] = profile;
          }
        }
      }

      final requestsWithSenderDetails = <Map<String, dynamic>>[];
      for (final request in requestsData) {
        final mapped = Map<String, dynamic>.from(request);
        final senderId = mapped['sender_id']?.toString();
        if (senderId != null && sendersById.containsKey(senderId)) {
          mapped['sender'] = sendersById[senderId];
        }
        requestsWithSenderDetails.add(mapped);
      }

      setState(() {
        _connectionRequests = requestsWithSenderDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading requests: $e');
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
                    'Error loading requests: $e',
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

  Future<void> _handleRequest(
    String requestId,
    String status,
    String senderName,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      if (status == 'accepted') {
        await supabase
            .from('connection_requests')
            .update({'status': status})
            .eq('id', requestId);

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
                      'Connection request accepted!',
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
      } else if (status == 'declined') {
        // Show confirmation dialog before declining
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
                      label: 'Decline',
                      action: () => Navigator.pop(context, true),
                      isDestructive: true,
                    ),
                  ],
                );
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
                final borderColor = isDark ? const Color(0xFF2B3A55) : const Color(0xFFE2E8F0);
                final titleColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF020817);
                final mutedTextColor = isDark ? const Color(0xFFA8B3C7) : const Color(0xFF64748B);
                final dangerSoft = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
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
                          Icons.close_rounded,
                          color: Color(0xFFEF4444),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Decline Request?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you sure you want to decline the connection request from $senderName?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: mutedTextColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Decline',
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
                );
              },
            ).then((_) {
              _updateTouchBar();
            });

        if (confirm != true) return;

        await supabase.from('connection_requests').delete().eq('id', requestId);

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
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Connection request declined',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF64748B),
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

      await _loadConnectionRequests();
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
                    'Error handling request: $e',
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2B3A55) : const Color(0xFFE2E8F0);
    final panelColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final titleColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF020817);
    final mutedTextColor = isDark ? const Color(0xFFA8B3C7) : const Color(0xFF64748B);
    final onlineBorder = isDark ? const Color(0xFF111827) : Colors.white;
    final messageBorder = isDark ? const Color(0xFF2E4365) : const Color(0xFFDBEAFE);
    final deleteBorder = isDark ? const Color(0xFF3B4A60) : const Color(0xFFE2E8F0);
    final emptyBg = isDark ? const Color(0xFF1D2A3F) : const Color(0xFFF1F5F9);
    final headerIconBg = isDark ? const Color(0xFF3B2A1F) : const Color(0xFFFFF7ED);
    final roleChipBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    final roleChipText = isDark ? const Color(0xFFBFDBFE) : const Color(0xFF2563EB);

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
                          Icons.notifications_active_rounded,
                          color: Color(0xFFF97316),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Connection Requests',
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
                          border: Border.all(
                            color: borderColor,
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: mutedTextColor,
                            size: 20,
                          ),
                          onPressed: _loadConnectionRequests,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage incoming connection requests from other users',
                    style: TextStyle(fontSize: 14, color: mutedTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Request Cards
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _connectionRequests.isEmpty
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
                            'No connection requests',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'New connection requests will appear here',
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
                      itemCount: _connectionRequests.length,
                      itemBuilder: (context, index) {
                        final request = _connectionRequests[index];
                        final sender = request['sender'];
                        final senderName = sender?['name'] ?? 'Unknown';
                        final senderEmail = _emailOrMaskedId(sender);
                        final senderRole =
                            sender?['role'] ?? sender?['user_role'] ?? 'User';
                        final message = request['message'] ?? '';
                        final createdAt = DateTime.parse(request['created_at']);
                        final initials = senderName.isNotEmpty
                            ? senderName[0].toUpperCase()
                            : '?';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor,
                              width: 1,
                            ),
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
                                // User Info Row
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
                                            radius: 24,
                                            backgroundColor: Colors.transparent,
                                            child: Text(
                                              initials,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
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
                                              color: const Color(0xFFF97316),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: onlineBorder,
                                                width: 2.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            senderName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: titleColor,
                                              height: 1.3,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: roleChipBg,
                                                  borderRadius:
                                                      BorderRadius.circular(5),
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
                                              const Icon(
                                                Icons.access_time_rounded,
                                                size: 13,
                                                color: Color(0xFF8FA2BF),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${createdAt.month}/${createdAt.day}/${createdAt.year}',
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
                                  ],
                                ),

                                // Email
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: panelColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.email_outlined,
                                        size: 14,
                                        color: mutedTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        senderEmail,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: mutedTextColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF16A34A),
                                              Color(0xFF22C55E),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF16A34A,
                                              ).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () => _handleRequest(
                                            request['id'],
                                            'accepted',
                                            senderName,
                                          ),
                                          icon: const Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Accept',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _handleRequest(
                                          request['id'],
                                          'declined',
                                          senderName,
                                        ),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Decline',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: mutedTextColor,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          side: BorderSide(
                                            color: deleteBorder,
                                            width: 1,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _emailOrMaskedId(Map<String, dynamic>? profile) {
    final email = profile?['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    final id = profile?['id']?.toString() ?? '';
    if (id.length >= 4) return 'ID •••• ${id.substring(id.length - 4)}';
    return 'ID ••••';
  }
}
