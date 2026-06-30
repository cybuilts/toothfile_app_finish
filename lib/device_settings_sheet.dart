import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceSettingsSheet extends StatefulWidget {
  const DeviceSettingsSheet({
    super.key,
    required this.device,
    required this.onUpdated,
  });

  final Map<String, dynamic> device;
  final Future<void> Function() onUpdated;

  @override
  State<DeviceSettingsSheet> createState() => _DeviceSettingsSheetState();
}

class _DeviceSettingsSheetState extends State<DeviceSettingsSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _pathController;
  late bool _notificationsEnabled;
  late bool _autoDownload;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: (widget.device['device_name'] as String?) ?? 'My Device',
    );
    _pathController = TextEditingController(
      text: (widget.device['storage_path'] as String?) ?? '',
    );
    _notificationsEnabled = widget.device['notifications_enabled'] == true;
    _autoDownload = widget.device['auto_download'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('devices').update({
        'device_name': _nameController.text.trim().isEmpty
            ? 'My Device'
            : _nameController.text.trim(),
        'notifications_enabled': _notificationsEnabled,
        'auto_download': _autoDownload,
        'storage_path': _pathController.text.trim(),
      }).eq('id', widget.device['id']);

      if (!mounted) return;
      await widget.onUpdated();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device?'),
        content: const Text(
          'This will remove the device from your account. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('devices')
          .delete()
          .eq('id', widget.device['id']);
      if (!mounted) return;
      await widget.onUpdated();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickFolder() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Download Folder',
    );
    if (selected == null || selected.trim().isEmpty) return;
    _pathController.text = selected;
    if (mounted) setState(() {});
  }

  String _formatLastSeen() {
    final raw = widget.device['last_seen_at']?.toString();
    if (raw == null || raw.isEmpty) return 'Unknown';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return 'Unknown';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
    final textColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF020817);
    final subText = isDark ? const Color(0xFFA8B3C7) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF2B3A55) : const Color(0xFFE2E8F0);
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final softPanel = isDark ? const Color(0xFF1D2A3F) : const Color(0xFFF1F5F9);
    final infoBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final padBottom = MediaQuery.of(context).viewInsets.bottom + 16;

    final maxSheetWidth = screenWidth > 860 ? 760.0 : double.infinity;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: maxSheetWidth,
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.devices_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Device Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: widget.device['is_online'] == true
                                  ? const Color(0xFFDCFCE7)
                                  : softPanel,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.device['is_online'] == true
                                  ? 'Online'
                                  : 'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.device['is_online'] == true
                                    ? const Color(0xFF16A34A)
                                    : subText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage this device behavior',
                        style: TextStyle(fontSize: 13, color: subText),
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
                    icon: Icon(Icons.close_rounded, color: subText, size: 20),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: subText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: 'Device Name',
                      filled: true,
                      fillColor: fieldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pathController,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: 'Download Folder Path',
                      filled: true,
                      fillColor: fieldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      suffixIcon: IconButton(
                        onPressed: _saving ? null : _pickFolder,
                        icon: const Icon(Icons.folder_open_rounded),
                        tooltip: 'Browse folder',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Behavior',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: subText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: infoBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Push Notifications',
                            style: TextStyle(color: textColor),
                          ),
                          subtitle: Text(
                            'Enable notification alerts on this device',
                            style: TextStyle(color: subText, fontSize: 12),
                          ),
                          value: _notificationsEnabled,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _notificationsEnabled = v),
                        ),
                        Divider(height: 1, color: border),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-Download Files',
                            style: TextStyle(color: textColor),
                          ),
                          subtitle: Text(
                            'Automatically save new incoming files',
                            style: TextStyle(color: subText, fontSize: 12),
                          ),
                          value: _autoDownload,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _autoDownload = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Device Info',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: subText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: infoBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.memory_rounded,
                          label: 'Platform',
                          value: (widget.device['platform'] ?? 'unknown')
                              .toString(),
                          textColor: textColor,
                          subText: subText,
                        ),
                        Divider(height: 18, color: border),
                        _buildInfoRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'Device ID',
                          value: (widget.device['device_id'] ?? '')
                              .toString()
                              .substring(
                                0,
                                ((widget.device['device_id'] ?? '')
                                            .toString()
                                            .length >
                                        24)
                                    ? 24
                                    : (widget.device['device_id'] ?? '')
                                        .toString()
                                        .length,
                              ),
                          textColor: textColor,
                          subText: subText,
                        ),
                        Divider(height: 18, color: border),
                        _buildInfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Last Seen',
                          value: _formatLastSeen(),
                          textColor: textColor,
                          subText: subText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, padBottom),
            decoration: BoxDecoration(
              color: sheetColor,
              border: Border(top: BorderSide(color: border, width: 1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _deleteDevice,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text(
                      'Remove Device',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _saving
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
                                ),
                          color: _saving ? softPanel : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.transparent,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
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
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subText,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subText),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: subText),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
