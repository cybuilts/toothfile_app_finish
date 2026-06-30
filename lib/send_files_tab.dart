import 'package:toothfile/send_files_page.dart';
import 'package:flutter/material.dart';
import 'package:toothfile/quick_share_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:touch_bar/touch_bar.dart';

class SendFilesTab extends StatefulWidget {
  const SendFilesTab({super.key});

  @override
  State<SendFilesTab> createState() => _SendFilesTabState();
}

class _SendFilesTabState extends State<SendFilesTab> {
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedRole = 'All Roles';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterUsers);
    _fetchUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTouchBar());
  }

  void _updateTouchBar() {
    TouchBarHelper.setDashboardTouchBar(
      extraItems: [
        TouchBarButton(label: 'Refresh', onClick: _fetchUsers),
        TouchBarButton(
          label: 'Filter: $_selectedRole',
          onClick: _showRoleFilter,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not logged in');
      }

      final connectionsResponse = await Supabase.instance.client
          .from('connection_requests')
          .select('sender_id, receiver_id')
          .eq('status', 'accepted')
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId');

      final List<String> connectedUserIds = [];
      for (var connection in connectionsResponse) {
        if (connection['sender_id'] == currentUserId) {
          connectedUserIds.add(connection['receiver_id']);
        } else {
          connectedUserIds.add(connection['sender_id']);
        }
      }

      if (connectedUserIds.isEmpty) {
        setState(() {
          _users = [];
          _filteredUsers = [];
          _isLoading = false;
        });
        return;
      }

      final response = await Supabase.instance.client.rpc(
        'get_public_profiles',
        params: {'_ids': connectedUserIds},
      );
      final users = List<Map<String, dynamic>>.from(response)
        ..sort((a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()));

      setState(() {
        _users = users;
        _isLoading = false;
      });
      _filterUsers();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load users: ${e.toString()}';
        _isLoading = false;
      });
      print('Error fetching users: $e');
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = user['name']?.toLowerCase() ?? '';
        final email = _emailOrMaskedId(user).toLowerCase();
        final role =
            (user['role'] ?? user['user_role'] ?? '').toString().toLowerCase();
        final selectedRoleLc = _selectedRole.toLowerCase();

        final matchesSearch = name.contains(query) || email.contains(query);
        final matchesRole =
            _selectedRole == 'All Roles' || role.contains(selectedRoleLc);

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  String _emailOrMaskedId(Map<String, dynamic> profile) {
    final email = profile['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    final id = profile['id']?.toString() ?? '';
    if (id.length >= 4) return 'ID •••• ${id.substring(id.length - 4)}';
    return 'ID ••••';
  }

  void _showRoleFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final roleSelectedBg = isDark
        ? const Color(0xFF2A1F46)
        : const Color(0xFFF3E8FF);
    final roleSelectedBorder = isDark
        ? const Color(0xFF5B3F8C)
        : const Color(0xFFD8B4FE);
    final roleUnselectedIconBg = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFF1F5F9);
    final roleSelectedText = isDark
        ? const Color(0xFFD8B4FE)
        : const Color(0xFF5B21B6);
    final roleUnselectedText = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF0F172A);
    final roleUnselectedIcon = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        TouchBarHelper.setPopupTouchBar(
          context: context,
          actions: [
            TouchBarHelperAction(
              label: 'All Roles',
              action: () {
                setState(() {
                  _selectedRole = 'All Roles';
                  _filterUsers();
                  _updateTouchBar();
                });
                Navigator.pop(context);
              },
            ),
            TouchBarHelperAction(
              label: 'Dental Practice',
              action: () {
                setState(() {
                  _selectedRole = 'dental';
                  _filterUsers();
                  _updateTouchBar();
                });
                Navigator.pop(context);
              },
            ),
            TouchBarHelperAction(
              label: 'Dental Technician',
              action: () {
                setState(() {
                  _selectedRole = 'technician';
                  _filterUsers();
                  _updateTouchBar();
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
        return Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
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
                    'Filter by Role',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...['All Roles', 'dental', 'technician'].map((role) {
                final isSelected = _selectedRole == role;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRole = role;
                        _filterUsers();
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
                        color: isSelected ? roleSelectedBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? roleSelectedBorder
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF8B5CF6)
                                  : roleUnselectedIconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              role == 'dental'
                                  ? Icons.medical_services_rounded
                                  : role == 'technician'
                                  ? Icons.build_rounded
                                  : Icons.people_alt_rounded,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : roleUnselectedIcon,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              role == 'dental'
                                  ? 'Dental Practice'
                                  : role == 'technician'
                                  ? 'Dental Technician'
                                  : 'All Roles',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? roleSelectedText
                                    : roleUnselectedText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF8B5CF6),
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
        );
      },
    ).then((_) {
      _updateTouchBar();
    });
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
    final chipBg = isDark ? const Color(0xFF2A1F46) : const Color(0xFFF3E8FF);
    final chipText = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF8B5CF6);
    final emptyBg = isDark ? const Color(0xFF1D2A3F) : const Color(0xFFF1F5F9);
    final errorBg = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEF2F2);
    final headerIconBg = isDark
        ? const Color(0xFF2A1F46)
        : const Color(0xFFF3E8FF);

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
                          Icons.send_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Send Files',
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
                          onPressed: _fetchUsers,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share files with your connected dental technicians',
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
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
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
                      onPressed: _showRoleFilter,
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedRole != 'All Roles')
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  12,
                  isMobile ? 16 : 24,
                  0,
                ),
                child: Chip(
                  label: Text(_selectedRole),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _selectedRole = 'All Roles';
                      _filterUsers();
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

            // User List
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
                  : _filteredUsers.isEmpty
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
                              Icons.people_outline,
                              size: 64,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No connected users',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connect with users to share files',
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
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _buildUserCard(user, isMobile);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isMobile) {
    final userName = user['name'] ?? 'Unknown User';
    final userEmail = _emailOrMaskedId(user);
    final userRole = user['role'] ?? user['user_role'] ?? 'User';
    final userInitials = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
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
    final emailBg = isDark ? const Color(0xFF1D2A3F) : const Color(0xFFF1F5F9);
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
            // Header Row
            Row(
              children: [
                // Avatar with online indicator
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
                          userInitials,
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
                          border: Border.all(color: onlineBorder, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleChipBg,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              userRole,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: roleChipText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Email Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: emailBg,
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
                    userEmail,
                    style: TextStyle(fontSize: 13, color: mutedTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Button - Simplified to P2P Transfer Only
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Traditional file sending (P2P removed)
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (BuildContext context) {
                        return SendFilesDialog(
                          userData: user,
                          initialFilePaths:
                              QuickShareService.consumePendingFiles(),
                        );
                      },
                    ).then((_) => _updateTouchBar());
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.send_rounded, size: 20, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          'Send Files',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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
    );
  }
}
