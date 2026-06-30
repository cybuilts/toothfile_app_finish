import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService with WidgetsBindingObserver {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;
  RealtimeChannel? _autoDownloadChannel;

  String? _currentDeviceId;
  String _platform = 'unknown';
  bool _autoDownloadEnabled = false;
  String _storagePath = '';
  bool _observerAttached = false;

  String? get currentDeviceId => _currentDeviceId;

  Future<void> initializeForSignedInUser() async {
    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }

    await registerCurrentDevice();
    await _refreshDevicePreferences();
    _startHeartbeat();
    _startAutoDownloadListener();
  }

  Future<void> registerCurrentDevice() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final details = await _resolveCurrentDevice();
    _currentDeviceId = details.deviceId;
    _platform = details.platform;

    final existing = await _supabase
        .from('devices')
        .select('id')
        .eq('user_id', user.id)
        .eq('device_id', details.deviceId)
        .maybeSingle();

    final payload = {
      'user_id': user.id,
      'device_id': details.deviceId,
      'device_name': details.deviceName,
      'platform': details.platform,
      'is_online': true,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing == null) {
      payload['storage_path'] = await _defaultDownloadsPath();
    }

    await _supabase
        .from('devices')
        .upsert(payload, onConflict: 'user_id,device_id');
  }

  Future<void> markSignedOut() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _updateOnlineStatus(false);
    _autoDownloadChannel?.unsubscribe();
    _autoDownloadChannel = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_supabase.auth.currentUser == null) return;
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
      _updateOnlineStatus(true);
      _refreshDevicePreferences();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _updateOnlineStatus(false);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _updateOnlineStatus(true);
    });
    _updateOnlineStatus(true);
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    final user = _supabase.auth.currentUser;
    final deviceId = _currentDeviceId;
    if (user == null || deviceId == null) return;

    await _supabase
        .from('devices')
        .update({
          'is_online': isOnline,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id)
        .eq('device_id', deviceId);
  }

  Future<void> _refreshDevicePreferences() async {
    final user = _supabase.auth.currentUser;
    final deviceId = _currentDeviceId;
    if (user == null || deviceId == null) return;

    final row = await _supabase
        .from('devices')
        .select('auto_download,storage_path')
        .eq('user_id', user.id)
        .eq('device_id', deviceId)
        .maybeSingle();
    if (row == null) return;

    _autoDownloadEnabled = row['auto_download'] == true;
    _storagePath = (row['storage_path'] as String?)?.trim() ?? '';
  }

  void _startAutoDownloadListener() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _autoDownloadChannel?.unsubscribe();
    _autoDownloadChannel = _supabase
        .channel('auto-download-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'shared_files',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: user.id,
          ),
          callback: (payload) async {
            await _refreshDevicePreferences();
            if (!_autoDownloadEnabled) return;

            final record = payload.newRecord;
            final targetDeviceId = record['target_device_id']?.toString().trim();
            if (targetDeviceId != null &&
                targetDeviceId.isNotEmpty &&
                (_currentDeviceId == null || targetDeviceId != _currentDeviceId)) {
              return;
            }
            final filePath = record['file_path']?.toString();
            if (filePath == null || filePath.isEmpty) return;

            try {
              final Uint8List bytes = await _supabase.storage
                  .from('dental-files')
                  .download(filePath);
              await _saveDownloadedBytes(
                bytes: bytes,
                remotePath: filePath,
                preferredName: record['file_name']?.toString(),
              );
            } catch (e) {
              debugPrint('Auto-download failed: $e');
            }
          },
        )
        .subscribe();
  }

  Future<void> _saveDownloadedBytes({
    required Uint8List bytes,
    required String remotePath,
    String? preferredName,
  }) async {
    var targetDirPath = _storagePath;
    if (targetDirPath.isEmpty) {
      final downloads = await getDownloadsDirectory();
      targetDirPath = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
    }

    final dir = Directory(targetDirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final fallbackName = remotePath.split('/').last;
    final fileName = (preferredName?.trim().isNotEmpty ?? false)
        ? preferredName!.trim()
        : fallbackName;
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<String> _defaultDownloadsPath() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads.path;
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  Future<_DeviceDetails> _resolveCurrentDevice() async {
    final plugin = DeviceInfoPlugin();

    if (kIsWeb) {
      return _DeviceDetails(
        deviceId: 'web-${DateTime.now().millisecondsSinceEpoch}',
        deviceName: 'Web Browser',
        platform: 'web',
      );
    }

    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return _DeviceDetails(
        deviceId: info.id,
        deviceName: '${info.brand} ${info.model}',
        platform: 'android',
      );
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return _DeviceDetails(
        deviceId: info.identifierForVendor ?? 'ios-unknown',
        deviceName: info.name,
        platform: 'ios',
      );
    }
    if (Platform.isWindows) {
      final info = await plugin.windowsInfo;
      return _DeviceDetails(
        deviceId: info.deviceId,
        deviceName: info.computerName,
        platform: 'windows',
      );
    }
    if (Platform.isMacOS) {
      final info = await plugin.macOsInfo;
      return _DeviceDetails(
        deviceId: info.systemGUID ?? 'macos-unknown',
        deviceName: info.computerName,
        platform: 'macos',
      );
    }

    return _DeviceDetails(
      deviceId: '$_platform-${DateTime.now().millisecondsSinceEpoch}',
      deviceName: 'Unknown Device',
      platform: _platform,
    );
  }
}

class _DeviceDetails {
  const _DeviceDetails({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
}
