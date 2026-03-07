// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:touch_bar/touch_bar.dart';

class DirectoryTab extends StatefulWidget {
  const DirectoryTab({super.key});

  @override
  State<DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends State<DirectoryTab> {
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedRole = 'All Roles';
  Map<String, String> _connectionStatuses = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterUsers);
    _loadUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTouchBar());
  }

  void _updateTouchBar() {
    TouchBarHelper.setDashboardTouchBar(
      extraItems: [
        TouchBarButton(label: 'Refresh', onClick: _loadUsers),
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

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final usersData = await supabase
          .from('profiles')
          .select('id, name, email, role, created_at')
          .neq('id', currentUser.id)
          .order('created_at', ascending: false);

      final sentRequests = await supabase
          .from('connection_requests')
          .select('receiver_id, status')
          .eq('sender_id', currentUser.id);

      final receivedRequests = await supabase
          .from('connection_requests')
          .select('sender_id, status')
          .eq('receiver_id', currentUser.id);

      Map<String, String> statuses = {};
      for (var request in sentRequests) {
        statuses[request['receiver_id']] = 'sent_${request['status']}';
      }
      for (var request in receivedRequests) {
        statuses[request['sender_id']] = 'received_${request['status']}';
      }

      setState(() {
        _users = List<Map<String, dynamic>>.from(usersData);
        _connectionStatuses = statuses;
        _filteredUsers = _users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
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
                    'Error loading users: $e',
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

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['name'] as String?)?.toLowerCase() ?? '';
        final email = (user['email'] as String?)?.toLowerCase() ?? '';

        final matchesSearch = name.contains(query) || email.contains(query);
        final matchesRole =
            _selectedRole == 'All Roles' || user['role'] == _selectedRole;

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _sendConnectionRequest(
    String receiverId,
    String receiverName,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) return;

      String? message =
          await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              final messageController = TextEditingController();
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final sheetColor = isDark
                  ? const Color(0xFF111827)
                  : Colors.white;
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
              final inputColor = isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF8FAFC);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: sheetColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border(
                      top: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Connect with $receiverName',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add an optional message to introduce yourself',
                        style: TextStyle(fontSize: 14, color: mutedTextColor),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: messageController,
                        maxLines: 4,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Hi, I\'d like to connect with you...',
                          hintStyle: TextStyle(color: hintTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: inputColor,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
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
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(
                                context,
                                messageController.text,
                              ),
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text(
                                'Send Request',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ).then((val) {
            _updateTouchBar();
            return val;
          });

      if (message == null) return;

      await supabase.from('connection_requests').insert({
        'sender_id': currentUser.id,
        'receiver_id': receiverId,
        'message': message.isEmpty ? null : message,
        'status': 'pending',
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
                    'Connection request sent!',
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

      await _loadUsers();
    } catch (e) {
      print('Error sending connection request: $e');
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
                    'Error sending request: $e',
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

  UserStatus _getUserStatus(String userId) {
    final status = _connectionStatuses[userId];
    if (status == null) return UserStatus.connectAndShare;
    if (status == 'sent_pending') return UserStatus.requestSent;
    if (status == 'sent_accepted' || status == 'received_accepted') {
      return UserStatus.connected;
    }
    return UserStatus.connectAndShare;
  }

  void _showRoleFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
        final borderColor = isDark
            ? const Color(0xFF2B3A55)
            : const Color(0xFFE2E8F0);
        final titleColor = isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF020817);
        final selectedBg = isDark
            ? const Color(0xFF1E3A8A)
            : const Color(0xFFEFF6FF);
        final selectedBorder = isDark
            ? const Color(0xFF3B82F6)
            : const Color(0xFFBFDBFE);
        final selectedText = isDark
            ? const Color(0xFFBFDBFE)
            : const Color(0xFF1E3A8A);
        final unselectedBg = isDark
            ? const Color(0xFF1D2A3F)
            : const Color(0xFFF1F5F9);
        final unselectedIcon = isDark
            ? const Color(0xFFA8B3C7)
            : const Color(0xFF64748B);
        final unselectedText = isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF0F172A);
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
                                  ? const Color(0xFF2563EB)
                                  : unselectedBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              role == 'dental'
                                  ? Icons.medical_services_rounded
                                  : role == 'technician'
                                  ? Icons.build_rounded
                                  : Icons.people_alt_rounded,
                              size: 16,
                              color: isSelected ? Colors.white : unselectedIcon,
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
                                    ? selectedText
                                    : unselectedText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF2563EB),
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
    ).then((_) => _updateTouchBar());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
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
    final chipBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    final chipText = isDark ? const Color(0xFFBFDBFE) : const Color(0xFF2563EB);
    final emptyBg = isDark ? const Color(0xFF1D2A3F) : const Color(0xFFF1F5F9);
    final headerIconBg = isDark
        ? const Color(0xFF3B2A1F)
        : const Color(0xFFFFF7ED);

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
                          Icons.people,
                          color: Color(0xFFF97316),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Users Directory',
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
                          onPressed: _loadUsers,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect with dental technicians',
                    style: TextStyle(fontSize: 14, color: mutedTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search and Filter Row
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
                          hintText: 'Search users...',
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

            const SizedBox(height: 16),

            // User Cards
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
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
                            'No users found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters',
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
                        final name = user['name'] ?? 'Unknown';
                        final email = user['email'] ?? 'N/A';
                        final role = user['role'] ?? 'User';
                        final createdAt = DateTime.parse(user['created_at']);
                        final initial = name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?';
                        final status = _getUserStatus(user['id']);

                        return UserCard(
                          initial: initial,
                          name: name,
                          role: role,
                          email: email,
                          joinedDate:
                              '${createdAt.month}/${createdAt.day}/${createdAt.year}',
                          status: status,
                          isMobile: isMobile,
                          onPressed: () {
                            if (status == UserStatus.connectAndShare) {
                              _sendConnectionRequest(user['id'], name);
                            }
                          },
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

enum UserStatus { connectAndShare, requestSent, connected }

class UserCard extends StatelessWidget {
  final String initial;
  final String name;
  final String role;
  final String email;
  final String joinedDate;
  final UserStatus status;
  final bool isMobile;
  final VoidCallback onPressed;

  const UserCard({
    super.key,
    required this.initial,
    required this.name,
    required this.role,
    required this.email,
    required this.joinedDate,
    required this.status,
    this.isMobile = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
    final roleChipBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final roleChipText = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF2563EB);
    final infoPanel = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFF1F5F9);
    final onlineBorder = isDark ? const Color(0xFF111827) : Colors.white;
    Color statusColor;
    String buttonText;
    IconData buttonIcon;
    Color buttonBackgroundColor;
    Color buttonForegroundColor;
    bool isEnabled;

    switch (status) {
      case UserStatus.connectAndShare:
        statusColor = const Color(0xFF2563EB);
        buttonText = 'Connect & Share';
        buttonIcon = Icons.send_rounded;
        buttonBackgroundColor = const Color(0xFF2563EB);
        buttonForegroundColor = Colors.white;
        isEnabled = true;
        break;
      case UserStatus.requestSent:
        statusColor = const Color(0xFFF97316);
        buttonText = 'Request Sent';
        buttonIcon = Icons.schedule_rounded;
        buttonBackgroundColor = isDark
            ? const Color(0xFF3B2A1F)
            : const Color(0xFFFFF7ED);
        buttonForegroundColor = isDark
            ? const Color(0xFFFCD34D)
            : const Color(0xFFF97316);
        isEnabled = false;
        break;
      case UserStatus.connected:
        statusColor = const Color(0xFF22C55E);
        buttonText = 'Connected';
        buttonIcon = Icons.check_circle_rounded;
        buttonBackgroundColor = isDark
            ? const Color(0xFF1B3A2A)
            : const Color(0xFFF0FDF4);
        buttonForegroundColor = isDark
            ? const Color(0xFF86EFAC)
            : const Color(0xFF22C55E);
        isEnabled = false;
        break;
    }

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar and Name Row
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
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                          height: 1.3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: roleChipBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: roleChipText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Email Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: infoPanel,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.email_outlined,
                    color: mutedTextColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedTextColor,
                      height: 1.4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Joined Date Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: infoPanel,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: mutedTextColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Joined $joinedDate',
                  style: TextStyle(
                    fontSize: 13,
                    color: mutedTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? onPressed : null,
                icon: Icon(buttonIcon, size: 18),
                label: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBackgroundColor,
                  foregroundColor: buttonForegroundColor,
                  disabledBackgroundColor: buttonBackgroundColor,
                  disabledForegroundColor: buttonForegroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
