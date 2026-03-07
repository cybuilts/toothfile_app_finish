// ignore_for_file: unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toothfile/delete_account_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toothfile/push_notification_service.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';
import 'package:touch_bar/touch_bar.dart';
import 'package:toothfile/main.dart';
import 'package:toothfile/supabase_auth_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _userName = 'User';
  String _userRole = 'Role';
  String _userid = 'U';
  String _useremail = 'email@example.com';
  String _createdAt = '0000-00-00';
  String? _downloadPath;
  bool _updatingDownloadPath = false;
  bool _openLocationAfterDownload = false;
  String? _selectedAppIcon;
  bool _pushEnabled = false;
  bool _notifFileReceived = true;
  bool _notifFileTracker = true;
  bool _notifConnectionRequests = true;
  bool _notifConnectionAccepted = true;
  String _selectedTheme = 'system'; // light, dark, system

  @override
  void initState() {
    final user = Supabase.instance.client.auth.currentUser;
    _userName = user?.userMetadata?['name']?.toString() ?? 'name';
    _userRole =
        user?.userMetadata?['role']?.toString() ??
        user?.userMetadata?['user_role']?.toString() ??
        'role';
    _useremail = user?.email ?? 'email';
    _userid = user?.id ?? 'uid';
    _createdAt = user?.createdAt ?? '0000-00-00';
    _loadDownloadPath();
    _loadPushEnabled();
    _loadNotificationPrefs();
    _loadThemePreference();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTouchBar());
  }

  Widget _buildThemeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final themeIconBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final themeIconColor = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF2563EB);
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeIconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: themeIconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Theme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildThemeOption(
                  'Light',
                  Icons.light_mode_rounded,
                  'light',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  'Dark',
                  Icons.dark_mode_rounded,
                  'dark',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  'System',
                  Icons.settings_suggest_rounded,
                  'system',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String label, IconData icon, String theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedTheme == theme;
    final selectedBackground = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final selectedBorder = isDark
        ? const Color(0xFF3B82F6)
        : const Color(0xFF2563EB);
    final selectedText = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF2563EB);
    final unselectedBackground = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final unselectedBorder = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final unselectedText = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    return GestureDetector(
      onTap: () => _saveThemePreference(theme),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? selectedBackground : unselectedBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorder : unselectedBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? selectedText : unselectedText,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? selectedText : unselectedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveThemePreference(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme', theme);
    updateAppThemeMode(theme);
    setState(() => _selectedTheme = theme);

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
            Expanded(
              child: Text(
                'Theme changed to ${theme[0].toUpperCase() + theme.substring(1)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }

  void _updateTouchBar() {
    TouchBarHelper.setDashboardTouchBar(
      extraItems: [
        TouchBarButton(
          label: 'Save Profile',
          backgroundColor: Colors.blue,
          onClick: _saveProfile,
        ),
        TouchBarButton(
          label: 'Sign Out',
          backgroundColor: Colors.red,
          onClick: _logout,
        ),
      ],
    );
  }

  Future<void> _logout() async {
    await SupabaseAuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MyApp()),
      (route) => false,
    );
  }

  Future<void> _saveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No user signed in'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    try {
      final res = await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'name': _userName}),
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'role': _userRole}),
      );

      final updatedUser = res.user;
      if (updatedUser != null) {
        setState(() {
          _userName =
              updatedUser.userMetadata?['name']?.toString() ?? _userName;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _loadDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
      () => _openLocationAfterDownload =
          prefs.getBool('open_download_location') ?? false,
    );
    setState(
      () => _selectedAppIcon =
          prefs.getString('app_icon_asset') ?? 'assets/logo.png',
    );
    final saved = prefs.getString('download_path');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _downloadPath = saved);
      return;
    }
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isAndroid) {
      final ext = await getExternalStorageDirectory();
      setState(() => _downloadPath = ext?.path);
      return;
    }
    if (isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      setState(() => _downloadPath = docs.path);
      return;
    }
    try {
      final downloadsDir = await getDownloadsDirectory();
      setState(() => _downloadPath = downloadsDir?.path);
    } catch (_) {
      final docs = await getApplicationDocumentsDirectory();
      setState(() => _downloadPath = docs.path);
    }
  }

  Future<void> _loadPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _pushEnabled = prefs.getBool('push_enabled') ?? false);
  }

  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifFileReceived = prefs.getBool('notif_file_received') ?? true;
      _notifFileTracker = prefs.getBool('notif_file_tracker') ?? true;
      _notifConnectionRequests =
          prefs.getBool('notif_connection_requests') ?? true;
      _notifConnectionAccepted =
          prefs.getBool('notif_connection_accepted') ?? true;
    });
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
      () => _selectedTheme = prefs.getString('selected_theme') ?? 'system',
    );
  }

  Future<void> _setAppIcon(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_icon_asset', path);
    setState(() => _selectedAppIcon = path);
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
                'App icon updated',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }

  Widget _buildPushCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Push Notifications',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Spacer(),
              _pushEnabled
                  ? Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await PushNotificationService.sendTestNotification();
                          },
                          icon: const Icon(
                            Icons.notification_important_rounded,
                            size: 18,
                          ),
                          label: const Text('Test Notification'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            setState(() => _pushEnabled = false);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('push_enabled', false);
                            await PushNotificationService.disableNotifications();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Disable Push'),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: () async {
                        setState(() => _pushEnabled = true);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('push_enabled', true);
                        await PushNotificationService.ensurePermissionsAndSyncToken();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Enable Push Notifications'),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledBanner() {
    return Container(padding: const EdgeInsets.all(0.1));
  }

  Widget _buildPreferenceOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? const Color(0xFF273449)
        : const Color(0xFFE2E8F0);
    return Column(
      children: [
        _buildNotificationRow(
          icon: Icons.folder_shared_rounded,
          title: 'File Received',
          subtitle: 'Notify when someone shares a file with you',
          value: _notifFileReceived,
          onChanged: (v) async {
            setState(() => _notifFileReceived = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notif_file_received', v);
          },
        ),
        Divider(height: 24, color: dividerColor),
        _buildNotificationRow(
          icon: Icons.visibility_rounded,
          title: 'File Tracker',
          subtitle: 'Notify when someone downloads your file',
          value: _notifFileTracker,
          onChanged: (v) async {
            setState(() => _notifFileTracker = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notif_file_tracker', v);
          },
        ),
        Divider(height: 24, color: dividerColor),
        _buildNotificationRow(
          icon: Icons.person_add_rounded,
          title: 'Connection Requests',
          subtitle: 'Notify about new connection requests',
          value: _notifConnectionRequests,
          onChanged: (v) async {
            setState(() => _notifConnectionRequests = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notif_connection_requests', v);
          },
        ),
        Divider(height: 24, color: dividerColor),
        _buildNotificationRow(
          icon: Icons.check_circle_rounded,
          title: 'Connection Accepted',
          subtitle: 'Notify when someone accepts your connection request',
          value: _notifConnectionAccepted,
          onChanged: (v) async {
            setState(() => _notifConnectionAccepted = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notif_connection_accepted', v);
          },
        ),
      ],
    );
  }

  Future<void> _pickDownloadDirectory() async {
    setState(() => _updatingDownloadPath = true);
    try {
      String? picked;
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      if (isIOS) {
        final docs = await getApplicationDocumentsDirectory();
        picked = docs.path;
      } else if (isAndroid) {
        final ext = await getExternalStorageDirectory();
        picked = ext?.path;
      } else {
        picked = await FilePicker.platform.getDirectoryPath();
      }
      if (kIsWeb && (picked == null || picked.isEmpty)) {
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
                    Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Browser controls download location on Web',
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
      if (picked != null && picked.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('download_path', picked);
        setState(() => _downloadPath = picked);
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
                    'Download folder updated',
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
                  'Failed to update folder: $e',
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
    } finally {
      if (mounted) setState(() => _updatingDownloadPath = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final panelColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2B3A55) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF020817);
    final mutedTextColor = isDark ? const Color(0xFFA8B3C7) : const Color(0xFF64748B);
    final hintTextColor = isDark ? const Color(0xFF8FA2BF) : const Color(0xFF94A3B8);
    final dangerSoftColor = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
    final dangerFillA = isDark
        ? const Color(0xFFEF4444).withOpacity(0.12)
        : const Color(0xFFEF4444).withOpacity(0.05);
    final dangerFillB = isDark
        ? const Color(0xFFF87171).withOpacity(0.12)
        : const Color(0xFFF87171).withOpacity(0.05);
    final dangerBorder = isDark
        ? const Color(0xFFEF4444).withOpacity(0.5)
        : const Color(0xFFEF4444).withOpacity(0.3);
    final settingsIconBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final notificationsIconBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final profileIconBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final profileFieldIconBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final roleUnselectedBg = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFDBEAFE);
    final roleUnselectedText = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF2563EB);
    final filesIconBg = isDark
        ? const Color(0xFF1B3A2A)
        : const Color(0xFFDCFCE7);
    final downloadFolderIconBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final accountInfoIconBg = isDark
        ? const Color(0xFF1B3A2A)
        : const Color.fromARGB(255, 234, 255, 232);

    return Container(
      color: pageColor,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: settingsIconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: isMobile ? 22 : 24,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your account settings and preferences',
                style: TextStyle(fontSize: 14, color: mutedTextColor),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: notificationsIconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.notifications_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPushCard(),
                    const SizedBox(height: 16),
                    _pushEnabled
                        ? _buildPreferenceOptions()
                        : _buildDisabledBanner(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: profileIconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Display Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _userName,
                      onChanged: (value) {
                        setState(() {
                          _userName = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        hintStyle: TextStyle(color: hintTextColor),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: profileFieldIconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: Color(0xFF2563EB),
                            size: 18,
                          ),
                        ),
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
                        fillColor: panelColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _useremail,
                      readOnly: true,
                      decoration: InputDecoration(
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1D2A3F) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.email_rounded,
                            color: mutedTextColor,
                            size: 18,
                          ),
                        ),
                        suffixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: hintTextColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        filled: true,
                        fillColor: panelColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Email cannot be changed',
                      style: TextStyle(fontSize: 12, color: hintTextColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Account Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _userRole = 'technician';
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _userRole == 'technician'
                                ? const Color(0xFF2563EB)
                                : roleUnselectedBg,
                            foregroundColor: _userRole == 'technician'
                                ? Colors.white
                                : roleUnselectedText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Dental Technician',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _userRole = 'dental';
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _userRole == 'dental'
                                ? const Color(0xFF2563EB)
                                : roleUnselectedBg,
                            foregroundColor: _userRole == 'dental'
                                ? Colors.white
                                : roleUnselectedText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Dentist',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: filesIconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.folder_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Files',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure where downloaded files are saved',
                      style: TextStyle(fontSize: 13, color: mutedTextColor),
                    ),
                    const SizedBox(height: 16),
                    Container(
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
                              color: downloadFolderIconBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              color: Color(0xFF2563EB),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Download Folder',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: mutedTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _downloadPath ?? 'Loading... ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _updatingDownloadPath
                                ? null
                                : _pickDownloadDirectory,
                            icon: const Icon(
                              Icons.edit_location_alt_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Account Information Section
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accountInfoIconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Account Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'View your current account details',
                      style: TextStyle(fontSize: 13, color: mutedTextColor),
                    ),
                    const SizedBox(height: 20),
                    _buildAccountInfoRow('Name:', _userName),
                    Divider(height: 24, color: borderColor),
                    _buildAccountInfoRow('Email:', _useremail),
                    Divider(height: 24, color: borderColor),
                    _buildAccountInfoRow('User UID:', _userid),
                    Divider(height: 24, color: borderColor),
                    _buildAccountInfoRow('Role:', _userRole, isChip: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Theme Section
              _buildThemeCard(),

              const SizedBox(height: 20),

              // Danger Zone Section
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: dangerSoftColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Irreversible and destructive actions',
                      style: TextStyle(fontSize: 13, color: mutedTextColor),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [dangerFillA, dangerFillB],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dangerBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Once you delete your account, there is no going back. Please be certain.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Instead of showDialog:
                              // Use showModalBottomSheet:
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (BuildContext context) {
                                  return const DeleteAccountDialog();
                                },
                              ).then((_) {
                                _updateTouchBar();
                              });
                            },
                            icon: const Icon(Icons.delete_rounded, size: 18),
                            label: const Text(
                              'Delete Account',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFF1F5F9);
    final primaryText = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final secondaryText = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: secondaryText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: secondaryText),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF16A34A),
        ),
      ],
    );
  }

  Widget _buildAccountInfoRow(
    String label,
    String value, {
    bool isChip = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    final valueColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final chipBackground = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFDBEAFE);
    final chipText = isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          if (isChip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: chipBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: chipText,
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
