import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toothfile/device_service.dart';
import 'package:toothfile/device_settings_sheet.dart';
import 'package:toothfile/send_files_page.dart';

class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  RealtimeChannel? _channel;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'All Status';
  String _selectedPlatformFilter = 'All Platforms';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _fetchDevices();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    final data = await supabase
        .from('devices')
        .select()
        .eq('user_id', user.id)
        .order('last_seen_at', ascending: false);
    if (!mounted) return;
    setState(() {
      _devices = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  void _subscribeRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _channel = supabase
        .channel('devices-flutter-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          callback: (_) => _fetchDevices(),
        )
        .subscribe();
  }

  IconData _platformIcon(String platform) {
    if (platform == 'android' || platform == 'ios') {
      return Icons.phone_android;
    }
    if (platform == 'windows' || platform == 'macos') {
      return Icons.desktop_windows;
    }
    return Icons.devices;
  }

  String _formatLastSeen(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return 'Unknown';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDeviceSettings(Map<String, dynamic> device) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          DeviceSettingsSheet(device: device, onUpdated: _fetchDevices),
    );
  }

  List<Map<String, dynamic>> _getFilteredDevices() {
    var filtered = List<Map<String, dynamic>>.from(_devices);

    if (_selectedStatusFilter != 'All Status') {
      final wantOnline = _selectedStatusFilter == 'Online';
      filtered = filtered
          .where((d) => (d['is_online'] == true) == wantOnline)
          .toList();
    }

    if (_selectedPlatformFilter != 'All Platforms') {
      final wanted = _selectedPlatformFilter.toLowerCase();
      filtered = filtered.where((d) {
        final platform = (d['platform'] ?? '').toString().toLowerCase();
        return platform == wanted;
      }).toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return filtered;

    return filtered.where((d) {
      final name = (d['device_name'] ?? '').toString().toLowerCase();
      final platform = (d['platform'] ?? '').toString().toLowerCase();
      final deviceId = (d['device_id'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          platform.contains(query) ||
          deviceId.contains(query);
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
        final mutedText = isDark
            ? const Color(0xFFA8B3C7)
            : const Color(0xFF64748B);
        final groupBg = isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC);
        final selectedBg = isDark
            ? const Color(0xFF1E3A8A)
            : const Color(0xFFDBEAFE);
        final selectedBorder = isDark
            ? const Color(0xFF3B82F6)
            : const Color(0xFF93C5FD);
        final selectedText = isDark
            ? const Color(0xFFBFDBFE)
            : const Color(0xFF1E40AF);

        final statusOptions = ['All Status', 'Online', 'Offline'];
        final platformOptions = [
          'All Platforms',
          'android',
          'ios',
          'windows',
          'macos',
          'unknown',
        ];

        String tempStatus = _selectedStatusFilter;
        String tempPlatform = _selectedPlatformFilter;

        return StatefulBuilder(
          builder: (context, modalSetState) {
            Widget buildOption({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? selectedBorder : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 18,
                        color: selected ? selectedText : mutedText,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? selectedText : titleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Filter Devices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: groupBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: mutedText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...statusOptions.map(
                                (status) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: buildOption(
                                    label: status,
                                    selected: tempStatus == status,
                                    onTap: () {
                                      modalSetState(() => tempStatus = status);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: groupBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Platform',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: mutedText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...platformOptions.map(
                                (platform) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: buildOption(
                                    label: platform == 'All Platforms'
                                        ? platform
                                        : platform.toUpperCase(),
                                    selected: tempPlatform == platform,
                                    onTap: () {
                                      modalSetState(
                                        () => tempPlatform = platform,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  modalSetState(() {
                                    tempStatus = 'All Status';
                                    tempPlatform = 'All Platforms';
                                  });
                                },
                                child: const Text('Reset'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedStatusFilter = tempStatus;
                                    _selectedPlatformFilter = tempPlatform;
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendToSelf({String? targetDeviceId}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final userData = <String, dynamic>{
      'name':
          (user.userMetadata?['name']?.toString().trim().isNotEmpty ?? false)
          ? user.userMetadata!['name']
          : (user.email ?? 'My Account').split('@').first,
      'email': user.email ?? '',
      'role': user.userMetadata?['role']?.toString() ?? 'Account',
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendFilesDialog(
        userData: userData,
        receiverIdOverride: user.id,
        sourceDeviceId: DeviceService.instance.currentDeviceId,
        targetDeviceId: targetDeviceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final onlineCount = _devices.where((d) => d['is_online'] == true).length;
    final filteredDevices = _getFilteredDevices();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDevices,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              isMobile ? 16 : 24,
              isMobile ? 16 : 24,
              isMobile ? 16 : 24,
            ),
            children: [
              // ── Header ────────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.devices_rounded,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'My Devices',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF020817),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          onPressed: _fetchDevices,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your connected devices and quick self-sharing',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
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
                          decoration: const InputDecoration(
                            hintText: 'Search devices, platform, id...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color(0xFF94A3B8),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
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
                      child: IconButton(
                        icon: const Icon(
                          Icons.filter_list,
                          color: Color(0xFF64748B),
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

              if (_selectedStatusFilter != 'All Status' ||
                  _selectedPlatformFilter != 'All Platforms')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_selectedStatusFilter != 'All Status')
                        Chip(
                          label: Text(_selectedStatusFilter),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(
                              () => _selectedStatusFilter = 'All Status',
                            );
                          },
                          backgroundColor: const Color(0xFFDBEAFE),
                          labelStyle: const TextStyle(
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (_selectedPlatformFilter != 'All Platforms')
                        Chip(
                          label: Text(_selectedPlatformFilter.toUpperCase()),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(
                              () => _selectedPlatformFilter = 'All Platforms',
                            );
                          },
                          backgroundColor: const Color(0xFFDCFCE7),
                          labelStyle: const TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── Stats card ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Row(
                  children: [
                    _statItem(label: 'Total', value: '${_devices.length}'),
                    _verticalDivider(),
                    _statItem(
                      label: 'Online',
                      value: '$onlineCount',
                      valueColor: const Color(0xFF16A34A),
                    ),
                    _verticalDivider(),
                    _statItem(
                      label: 'Offline',
                      value: '${_devices.length - onlineCount}',
                      valueColor: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Send to all button (shown when >1 device) ─────────────
              if (!_loading && _devices.length > 1) ...[
                ElevatedButton.icon(
                  onPressed: () => _sendToSelf(),
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Send File To All Devices',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_loading)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Loading devices...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // ── Empty state ───────────────────────────────────────────
                if (filteredDevices.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.devices_outlined,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No devices found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF020817),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try adjusting your search or filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Device cards ──────────────────────────────────────────
                for (final device in filteredDevices)
                  _DeviceCard(
                    device: device,
                    platformIcon: _platformIcon(
                      (device['platform'] ?? '').toString(),
                    ),
                    formattedLastSeen: _formatLastSeen(
                      device['last_seen_at']?.toString(),
                    ),
                    onSettings: () => _showDeviceSettings(device),
                    onSend: () => _sendToSelf(
                      targetDeviceId: device['device_id']?.toString(),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    Color valueColor = const Color(0xFF020817),
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 48, color: const Color(0xFFE2E8F0));
  }
}

// ─── Device Card ──────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final IconData platformIcon;
  final String formattedLastSeen;
  final VoidCallback onSettings;
  final VoidCallback onSend;

  const _DeviceCard({
    required this.device,
    required this.platformIcon,
    required this.formattedLastSeen,
    required this.onSettings,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = device['is_online'] == true;
    final autoDownload = device['auto_download'] == true;
    final deviceName = (device['device_name'] ?? 'My Device').toString();
    final platform = (device['platform'] ?? 'unknown').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
            // Device name + status row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    platformIcon,
                    color: const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF020817),
                          fontSize: 16,
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
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              platform,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Online / Offline badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOnline
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Info rows
            _infoRow(
              icon: Icons.access_time_rounded,
              label: 'Last seen',
              value: formattedLastSeen,
            ),
            const SizedBox(height: 8),

            // Auto-download chip
            if (autoDownload)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.download_done_rounded,
                      size: 13,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Auto-download enabled',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                // Settings
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSettings,
                    icon: const Icon(
                      Icons.settings_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    label: const Text(
                      'Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Send
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSend,
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Send File',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF020817),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
