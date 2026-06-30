// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:touch_bar/touch_bar.dart';

class ForwardDialog extends StatefulWidget {
  final Map<String, dynamic>? fileRecord;
  final dynamic order;
  final VoidCallback? onForwarded;

  const ForwardDialog({
    super.key,
    this.fileRecord,
    this.order,
    this.onForwarded,
  });

  @override
  State<ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<ForwardDialog> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> _connections = [];
  String? _selectedUserId;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadConnections();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTouchBar());
  }

  void _updateTouchBar() {
    TouchBarHelper.setPopupTouchBar(
      context: context,
      actions: [
        TouchBarHelperAction(
          label: 'Cancel',
          action: () => Navigator.pop(context),
        ),
        if (_selectedUserId != null)
          TouchBarHelperAction(
            label: 'Forward',
            action: _forward,
            isPrimary: true,
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final sent = await client
          .from('connection_requests')
          .select('receiver_id,status')
          .eq('sender_id', user.id);
      final received = await client
          .from('connection_requests')
          .select('sender_id,status')
          .eq('receiver_id', user.id);
      final ids = <String>{};
      for (final r in (sent as List)) {
        if (r['status'] == 'accepted') ids.add(r['receiver_id']);
      }
      for (final r in (received as List)) {
        if (r['status'] == 'accepted') ids.add(r['sender_id']);
      }
      List<Map<String, dynamic>> profiles = [];
      if (ids.isNotEmpty) {
        final res = await client.rpc(
          'get_public_profiles',
          params: {'_ids': ids.toList()},
        );
        profiles = List<Map<String, dynamic>>.from(res as List);
      }
      setState(() {
        _connections = profiles;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
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
                    'Error loading connections: $e',
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

  Future<void> _forward() async {
    if (_selectedUserId == null) return;
    setState(() => _submitting = true);
    try {
      final current = client.auth.currentUser;
      if (current == null) {
        setState(() => _submitting = false);
        return;
      }
      if (widget.fileRecord != null) {
        final f = widget.fileRecord!;
        final fileName = f['file_name'];
        final filePath = f['file_path'];
        int? size = f['file_size'] as int?;
        String? type = f['file_type'] as String?;
        Map<String, dynamic>? me;
        try {
          final res = await client.rpc('get_my_profile');
          me = Map<String, dynamic>.from(res as Map);
        } catch (_) {}
        final fromName = (me?['name']?.toString().trim().isNotEmpty == true)
            ? me!['name'].toString()
            : (me?['email']?.toString() ?? 'User');
        final originalMsg = (f['message'] ?? '').toString().trim();
        final composedMsg =
            '[Forwarded from $fromName]' +
            (originalMsg.isNotEmpty ? ' $originalMsg' : '');
        if (size == null) {
          try {
            final data = await client.storage
                .from('dental-files')
                .download(filePath);
            size = data.length;
          } catch (_) {
            size = 0;
          }
        }
        type ??= (fileName is String && fileName.contains('.')
            ? fileName.split('.').last
            : 'unknown');
        await client.from('shared_files').insert({
          'sender_id': current.id,
          'receiver_id': _selectedUserId,
          'file_name': fileName,
          'file_path': filePath,
          'file_size': size,
          'file_type': type,
          'message': composedMsg,
          'customer_name': f['customer_name'],
          'selected_teeth': f['selected_teeth'],
          'tooth_color': f['tooth_color'],
          'order_id': f['order_id'],
        });
      } else if (widget.order != null) {
        final o = widget.order;
        await client.rpc(
          'forward_order',
          params: {
            'target_user_id': _selectedUserId,
            'p_customer_name': o.customerName,
            'p_technician_name': o.dentalTechnicianName,
            'p_tooth_color': o.toothColor,
            'p_selected_teeth': o.selectedTeeth,
            'p_details': o.orderDetails,
            'p_order_files': o.orderFiles,
            'p_forwarded_from': current.id,
          },
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onForwarded?.call();
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
                  'Forwarded successfully!',
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
    } catch (e) {
      setState(() => _submitting = false);
      if (!mounted) return;
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
                  'Forward failed: $e',
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final softPanel = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFF1F5F9);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final mutedTextColor = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    final hintTextColor = isDark
        ? const Color(0xFF8FA2BF)
        : const Color(0xFF94A3B8);
    final selectedCard = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final selectedCardBorder = isDark
        ? const Color(0xFF3B82F6)
        : const Color(0xFF2563EB);
    final selectedEmailColor = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF1E40AF);
    final roleChipBg = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFDBEAFE);
    final roleChipText = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF2563EB);
    final onlineBorder = isDark ? const Color(0xFF111827) : Colors.white;
    final filteredConnections = _connections.where((p) {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (p['name'] ?? '').toString().toLowerCase();
      final email = (p['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.forward_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forward',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select a connection to forward to',
                        style: TextStyle(fontSize: 13, color: mutedTextColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: softPanel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: mutedTextColor,
                      size: 20,
                    ),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
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
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search connections...',
                  hintStyle: TextStyle(color: hintTextColor),
                  prefixIcon: Icon(
                    Icons.search,
                    color: hintTextColor,
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Connections List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _connections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: softPanel,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No connections found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect with users to forward items',
                          style: TextStyle(fontSize: 14, color: mutedTextColor),
                        ),
                      ],
                    ),
                  )
                : filteredConnections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: softPanel,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No matches found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search',
                          style: TextStyle(fontSize: 14, color: mutedTextColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredConnections.length,
                    itemBuilder: (context, index) {
                      final p = filteredConnections[index];
                      final id = p['id'] as String;
                      final selected = _selectedUserId == id;
                      final name = p['name'] ?? 'Unknown';
                      final email = _emailOrMaskedId(p);
                      final role = p['role'] ?? p['user_role'] ?? 'User';
                      final initial = name.isNotEmpty
                          ? name[0].toUpperCase()
                          : 'U';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: selected ? selectedCard : cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? selectedCardBorder : borderColor,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedUserId = id);
                            _updateTouchBar();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
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
                                          initial,
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
                                          color: const Color(0xFF22C55E),
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
                                        name,
                                        style: TextStyle(
                                          fontSize: 15,
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? const Color(0xFF2563EB)
                                                  : roleChipBg,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              role,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: selected
                                                    ? Colors.white
                                                    : roleChipText,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: selected
                                                    ? selectedEmailColor
                                                    : mutedTextColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF16A34A),
                                          Color(0xFF22C55E),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: softPanel,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.circle_outlined,
                                      color: hintTextColor,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sheetColor,
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
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
                        color: mutedTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _selectedUserId != null && !_submitting
                          ? const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
                            )
                          : null,
                      color: _selectedUserId != null && !_submitting
                          ? null
                          : softPanel,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedUserId != null && !_submitting
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: ElevatedButton(
                      onPressed: (_selectedUserId == null || _submitting)
                          ? null
                          : _forward,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: _selectedUserId != null && !_submitting
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: const Color(0xFF94A3B8),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Forward',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
