// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toothfile/invite_collaborator_dialog.dart';
import 'package:toothfile/main.dart';
import 'package:toothfile/supabase_auth_service.dart';
import 'package:toothfile/received_files_tab.dart';
import 'package:toothfile/send_files_tab.dart';
import 'package:toothfile/file_tracker_tab.dart';
import 'package:toothfile/requests_tab.dart';
import 'package:toothfile/directory_tab.dart';
import 'package:toothfile/order_form_tab.dart';
import 'package:toothfile/devices_tab.dart';
import 'package:toothfile/settings_tab.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardPage extends StatefulWidget {
  final int? initialIndex;
  const DashboardPage({super.key, this.initialIndex});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _userName = 'User';
  String _userRole = 'Role';
  String _userEmail = '';
  String _userInitials = 'U';
  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  final GlobalKey _menuButtonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  List<Widget> get _pages => [
    const ReceivedFilesTab(),
    const SendFilesTab(),
    const FileTrackerTab(),
    const RequestsTab(),
    const DirectoryTab(),
    const OrderFormTab(),
    const DevicesTab(),
    const SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _userName = user?.userMetadata?['name']?.toString() ?? 'User';
    _userRole =
        user?.userMetadata?['user_role']?.toString() ??
        user?.userMetadata?['role']?.toString() ??
        'Role';
    _userEmail = user?.email ?? '';
    _userInitials = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
    _selectedIndex = widget.initialIndex ?? 0;

    // Set up global TouchBar callback
    TouchBarHelper.onTabSelect = (index) {
      if (index >= 0 && index < _pages.length) {
        setState(() {
          _selectedIndex = index;
        });
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Small delay to ensure window is ready and focused on macOS
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _setTouchBar();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setTouchBar();
  }

  void _setTouchBar() {
    TouchBarHelper.setDashboardTouchBar();
  }

  @override
  void dispose() {
    TouchBarHelper.onTabSelect = null;
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isMenuOpen = false;
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _removeOverlay();
      setState(() {});
    } else {
      _showMenu();
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showMenu() {
    final RenderBox renderBox =
        _menuButtonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final menuBackground = isDark ? const Color(0xFF0F172A) : Colors.white;
        final menuBorder = isDark
            ? const Color.fromARGB(255, 23, 37, 68)
            : const Color(0xFFE2E8F0);
        final primaryText = isDark
            ? const Color(0xFFE2E8F0)
            : const Color(0xFF020817);
        final secondaryText = isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B);
        final roleChipBg = isDark
            ? const Color(0xFF1E3A8A)
            : const Color(0xFFDBEAFE);
        final roleChipText = isDark
            ? const Color(0xFFBFDBFE)
            : const Color(0xFF2563EB);
        return Stack(
          children: [
            // Transparent barrier to detect outside taps
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _removeOverlay();
                  });
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            // The actual menu
            Positioned(
              top: offset.dy + size.height + 8,
              right: MediaQuery.of(context).size.width - offset.dx - size.width,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: menuBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: menuBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF2563EB),
                              radius: 20,
                              child: Text(
                                _userInitials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: primaryText,
                                    ),
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
                                          color: roleChipBg,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Text(
                                          _userRole,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: roleChipText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _userEmail,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: secondaryText,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                      Divider(height: 1, thickness: 1, color: menuBorder),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _removeOverlay();
                          });
                          // Instead of showDialog, use:
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (BuildContext context) {
                              return const InviteCollaboratorDialog();
                            },
                          ).then((_) {
                            _setTouchBar();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_add_alt_1_outlined,
                                size: 18,
                                color: secondaryText,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Invite',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          setState(() {
                            _removeOverlay();
                          });
                          await _openExternalUrl('https://toothfile.com/docs');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 18,
                                color: secondaryText,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Docs',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          setState(() {
                            _removeOverlay();
                          });
                          await _openExternalUrl(
                            'https://toothfile.com/download',
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.download_rounded,
                                size: 18,
                                color: secondaryText,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Download',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: menuBorder),
                      InkWell(
                        onTap: () async {
                          setState(() {
                            _removeOverlay();
                          });
                          await SupabaseAuthService.logout();
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
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Logged out successfully',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
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
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const MyApp(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout,
                                size: 18,
                                color: secondaryText,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isMenuOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final scaffoldColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final dividerColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final primaryText = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF020817);
    final secondaryText = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    return Scaffold(
      backgroundColor: scaffoldColor,
      body: Column(
        children: [
          // Header
          (!kIsWeb &&
                  (defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS))
              ? const SizedBox(height: 20)
              : const SizedBox.shrink(),
          Container(
            color: surfaceColor,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Row(
              children: [
                // Logo and Title
                FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snapshot) {
                    final iconPath = snapshot.hasData
                        ? (snapshot.data!.getString('app_icon_asset') ??
                              'assets/logo.png')
                        : 'assets/logo.png';
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(iconPath, width: 20, height: 20),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ToothFile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: secondaryText,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // User Menu Button
                GestureDetector(
                  key: _menuButtonKey,
                  onTap: _toggleMenu,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border.all(color: dividerColor, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF2563EB),
                          radius: 14,
                          child: Text(
                            _userInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isMenuOpen
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Welcome Section

          // Navigation Tabs
          Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildNavTab(0, Icons.download_outlined, 'Received Files'),
                  _buildNavTab(1, Icons.send_outlined, 'Send Files'),
                  _buildNavTab(2, Icons.insert_chart_outlined, 'File Tracker'),
                  _buildNavTab(3, Icons.notifications_outlined, 'Requests'),
                  _buildNavTab(4, Icons.people_outline, 'Directory'),
                  _buildNavTab(5, Icons.description_outlined, 'Order Form'),
                  _buildNavTab(6, Icons.devices_rounded, 'Devices'),
                  _buildNavTab(7, Icons.settings_outlined, 'Settings'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),

          // Divider
          Container(height: 1, color: dividerColor),

          // Content Area
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildNavTab(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBackground = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);
    final selectedBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final unselectedText = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final selectedText = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF020817);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            if (_isMenuOpen) {
              _removeOverlay();
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? selectedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? selectedBorder : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF2563EB) : unselectedText,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? selectedText : unselectedText,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
