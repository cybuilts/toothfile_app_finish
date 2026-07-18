import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toothfile/update_install_types.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_installer_stub.dart' if (dart.library.io) 'update_installer_io.dart'
    as update_installer;

class InstalledAppVersion {
  const InstalledAppVersion({
    required this.platform,
    required this.version,
    required this.buildNumber,
  });

  final String platform;
  final String version;
  final String buildNumber;

  String get releaseLabel =>
      buildNumber.isEmpty ? version : '$version+$buildNumber';
}

class RemoteUpdateInfo {
  const RemoteUpdateInfo({
    required this.releaseId,
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.mandatory,
    required this.releaseNotes,
    this.fileName,
    this.sourceName,
    this.minimumSupportedVersion,
    this.publishedAt,
  });

  final String releaseId;
  final String platform;
  final String version;
  final String buildNumber;
  final String downloadUrl;
  final bool mandatory;
  final List<String> releaseNotes;
  final String? fileName;
  final String? sourceName;
  final String? minimumSupportedVersion;
  final String? publishedAt;

  String get releaseLabel =>
      buildNumber.isEmpty ? version : '$version+$buildNumber';

  String get displayLabel => fileName?.trim().isNotEmpty == true
      ? fileName!
      : releaseLabel;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.installedVersion,
    this.availableUpdate,
    this.errorMessage,
  });

  final InstalledAppVersion installedVersion;
  final RemoteUpdateInfo? availableUpdate;
  final String? errorMessage;

  bool get hasUpdate => availableUpdate != null;
}

class _SourceForgeProjectConfig {
  const _SourceForgeProjectConfig({
    required this.project,
    required this.projectUrl,
    required this.filesUrl,
    required this.latestDownloadUrl,
  });

  final String project;
  final String projectUrl;
  final String filesUrl;
  final String latestDownloadUrl;
}

class UpdateService {
  static const String manifestUrl =
      'https://toothfile.com/app-updates/manifest.json';

  static const String _ignoredVersionKey = 'ignored_update_version';
  static const String _lastPromptedReleaseKey = 'last_prompted_update_release';

  static const Map<String, _SourceForgeProjectConfig> _sourceForgeProjects = {
    'android': _SourceForgeProjectConfig(
      project: 'toothfile',
      projectUrl: 'https://sourceforge.net/projects/toothfile/',
      filesUrl: 'https://sourceforge.net/projects/toothfile/files/',
      latestDownloadUrl:
          'https://sourceforge.net/projects/toothfile/files/latest/download',
    ),
    'ios': _SourceForgeProjectConfig(
      project: 'toothfile-ios',
      projectUrl: 'https://sourceforge.net/projects/toothfile-ios/',
      filesUrl: 'https://sourceforge.net/projects/toothfile-ios/files/',
      latestDownloadUrl:
          'https://sourceforge.net/projects/toothfile-ios/files/latest/download',
    ),
    'windows': _SourceForgeProjectConfig(
      project: 'toothfile-windows',
      projectUrl: 'https://sourceforge.net/projects/toothfile-windows/',
      filesUrl: 'https://sourceforge.net/projects/toothfile-windows/files/',
      latestDownloadUrl:
          'https://sourceforge.net/projects/toothfile-windows/files/latest/download',
    ),
    'macos': _SourceForgeProjectConfig(
      project: 'toothfile-macos',
      projectUrl: 'https://sourceforge.net/projects/toothfile-macos/',
      filesUrl: 'https://sourceforge.net/projects/toothfile-macos/files/',
      latestDownloadUrl:
          'https://sourceforge.net/projects/toothfile-macos/files/latest/download',
    ),
  };

  static Future<InstalledAppVersion> getInstalledVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return InstalledAppVersion(
      platform: currentPlatformKey,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  }

  static String get currentPlatformKey {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static Future<UpdateCheckResult> checkForUpdates() async {
    final installedVersion = await getInstalledVersion();

    try {
      final sourceForgeResult = await _checkSourceForgeForUpdates(
        installedVersion,
      );
      if (sourceForgeResult != null) {
        return sourceForgeResult;
      }

      final response = await http
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          installedVersion: installedVersion,
          errorMessage: 'Update server unavailable (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return UpdateCheckResult(
          installedVersion: installedVersion,
          errorMessage: 'Invalid update manifest.',
        );
      }

      final remoteInfo = _parsePlatformInfo(
        decoded,
        installedVersion.platform,
      );

      if (remoteInfo == null) {
        return UpdateCheckResult(installedVersion: installedVersion);
      }

      final versionComparison = _compareVersionStrings(
        remoteInfo.version,
        installedVersion.version,
      );
      final buildComparison = _compareBuildNumbers(
        remoteInfo.buildNumber,
        installedVersion.buildNumber,
      );
      final shouldUpdate =
          versionComparison > 0 || (versionComparison == 0 && buildComparison > 0);

      if (!shouldUpdate) {
        return UpdateCheckResult(installedVersion: installedVersion);
      }

      final minimumSupportedVersion = remoteInfo.minimumSupportedVersion;
      final isMandatory =
          remoteInfo.mandatory ||
          (minimumSupportedVersion != null &&
              minimumSupportedVersion.isNotEmpty &&
              _compareVersionStrings(
                    installedVersion.version,
                    minimumSupportedVersion,
                  ) <
                  0);

      return UpdateCheckResult(
        installedVersion: installedVersion,
        availableUpdate: RemoteUpdateInfo(
          releaseId: remoteInfo.releaseId,
          platform: remoteInfo.platform,
          version: remoteInfo.version,
          buildNumber: remoteInfo.buildNumber,
          downloadUrl: remoteInfo.downloadUrl,
          mandatory: isMandatory,
          releaseNotes: remoteInfo.releaseNotes,
          fileName: remoteInfo.fileName,
          sourceName: remoteInfo.sourceName,
          minimumSupportedVersion: remoteInfo.minimumSupportedVersion,
          publishedAt: remoteInfo.publishedAt,
        ),
      );
    } catch (_) {
      return UpdateCheckResult(
        installedVersion: installedVersion,
        errorMessage: 'Unable to check for updates right now.',
      );
    }
  }

  static Future<bool> shouldPromptForUpdate(RemoteUpdateInfo update) async {
    if (update.mandatory) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ignoredVersionKey) != update.releaseId &&
        prefs.getString(_lastPromptedReleaseKey) != update.releaseId;
  }

  static Future<void> ignoreUpdate(RemoteUpdateInfo update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoredVersionKey, update.releaseId);
  }

  static Future<void> clearIgnoredUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ignoredVersionKey);
  }

  static Future<void> markPrompted(RemoteUpdateInfo update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPromptedReleaseKey, update.releaseId);
  }

  static Future<bool> openUpdate(RemoteUpdateInfo update) async {
    if (update.downloadUrl.trim().isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(update.downloadUrl);
    if (uri == null) {
      return false;
    }
    return launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );
  }

  static bool get supportsInAppInstall {
    final platform = currentPlatformKey;
    return platform == 'windows' || platform == 'android' || platform == 'macos';
  }

  static bool get supportsAutomaticBackgroundInstall {
    return currentPlatformKey == 'windows';
  }

  static Future<UpdateInstallResult> downloadAndInstallUpdate(
    RemoteUpdateInfo update, {
    UpdateProgressCallback? onProgress,
  }) {
    return update_installer.downloadAndInstallUpdate(
      platform: currentPlatformKey,
      downloadUrl: update.downloadUrl,
      fileName: update.fileName,
      onProgress: onProgress,
    );
  }

  static Future<void> exitForInstall() {
    return update_installer.exitForInstall();
  }

  static RemoteUpdateInfo? _parsePlatformInfo(
    Map<String, dynamic> manifest,
    String platform,
  ) {
    Map<String, dynamic>? platforms;

    final platformsNode = manifest['platforms'];
    if (platformsNode is Map<String, dynamic>) {
      platforms = platformsNode;
    } else if (manifest[platform] is Map<String, dynamic>) {
      platforms = manifest;
    } else {
      final releasesNode = manifest['releases'];
      if (releasesNode is Map<String, dynamic>) {
        platforms = releasesNode;
      }
    }

    if (platforms == null) {
      return null;
    }

    final dynamic rawPlatformInfo = platforms[platform];
    if (rawPlatformInfo is! Map<String, dynamic>) {
      return null;
    }

    final version = rawPlatformInfo['version']?.toString().trim() ?? '';
    final buildNumber =
        rawPlatformInfo['buildNumber']?.toString().trim() ??
        rawPlatformInfo['build']?.toString().trim() ??
        '';
    final downloadUrl =
        rawPlatformInfo['downloadUrl']?.toString().trim() ??
        rawPlatformInfo['url']?.toString().trim() ??
        '';

    if (version.isEmpty || downloadUrl.isEmpty) {
      return null;
    }

    final releaseNotes = <String>[];
    final rawNotes = rawPlatformInfo['releaseNotes'];
    if (rawNotes is List) {
      for (final item in rawNotes) {
        final note = item?.toString().trim() ?? '';
        if (note.isNotEmpty) {
          releaseNotes.add(note);
        }
      }
    } else if (rawNotes is String && rawNotes.trim().isNotEmpty) {
      releaseNotes.add(rawNotes.trim());
    }

    return RemoteUpdateInfo(
      releaseId:
          rawPlatformInfo['releaseId']?.toString().trim().isNotEmpty == true
          ? rawPlatformInfo['releaseId']!.toString().trim()
          : '$platform:$version+$buildNumber',
      platform: platform,
      version: version,
      buildNumber: buildNumber,
      downloadUrl: downloadUrl,
      mandatory: rawPlatformInfo['mandatory'] == true,
      releaseNotes: releaseNotes,
      fileName: rawPlatformInfo['fileName']?.toString().trim(),
      sourceName: rawPlatformInfo['sourceName']?.toString().trim(),
      minimumSupportedVersion:
          rawPlatformInfo['minimumSupportedVersion']?.toString().trim(),
      publishedAt: rawPlatformInfo['publishedAt']?.toString(),
    );
  }

  static Future<UpdateCheckResult?> _checkSourceForgeForUpdates(
    InstalledAppVersion installedVersion,
  ) async {
    final config = _sourceForgeProjects[installedVersion.platform];
    if (config == null) {
      return null;
    }

    final remoteInfo = await _fetchSourceForgeRelease(
      config: config,
      platform: installedVersion.platform,
    );
    if (remoteInfo == null) {
      return null;
    }

    final extractedVersion = _extractVersionFromFileName(remoteInfo.fileName ?? '');
    final shouldUpdate = extractedVersion != null
        ? _compareVersionStrings(
              extractedVersion,
              installedVersion.version,
            ) >
            0
        : true;

    return UpdateCheckResult(
      installedVersion: installedVersion,
      availableUpdate: shouldUpdate ? remoteInfo : null,
    );
  }

  static Future<RemoteUpdateInfo?> _fetchSourceForgeRelease({
    required _SourceForgeProjectConfig config,
    required String platform,
  }) async {
    try {
      final bestReleaseResponse = await http
          .get(
            Uri.parse(
              'https://sourceforge.net/projects/${config.project}/best_release.json',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (bestReleaseResponse.statusCode == 200) {
        final decoded = jsonDecode(bestReleaseResponse.body);
        if (decoded is Map<String, dynamic>) {
          final parsed = _parseSourceForgeBestRelease(
            decoded: decoded,
            config: config,
            platform: platform,
          );
          if (parsed != null) {
            return parsed;
          }
        }
      }
    } catch (_) {}

    try {
      final filesResponse = await http
          .get(Uri.parse(config.filesUrl))
          .timeout(const Duration(seconds: 8));
      if (filesResponse.statusCode != 200) {
        return null;
      }
      return _parseSourceForgeFilesPage(
        html: filesResponse.body,
        config: config,
        platform: platform,
      );
    } catch (_) {
      return null;
    }
  }

  static RemoteUpdateInfo? _parseSourceForgeBestRelease({
    required Map<String, dynamic> decoded,
    required _SourceForgeProjectConfig config,
    required String platform,
  }) {
    final releaseNode = decoded['release'];
    if (releaseNode is! Map<String, dynamic>) {
      return null;
    }

    final filePath = releaseNode['filename']?.toString().trim() ?? '';
    final fileName = filePath.split('/').last.trim();
    final publishedAt =
        releaseNode['date_modified']?.toString().trim().isNotEmpty == true
        ? releaseNode['date_modified']!.toString().trim()
        : releaseNode['date']?.toString().trim();
    final downloadUrl =
        _normalizeSourceForgeDownloadUrl(
          releaseNode['url']?.toString().trim(),
        ) ??
        config.latestDownloadUrl;
    final releaseId =
        releaseNode['sf_file_id']?.toString().trim().isNotEmpty == true
        ? '${config.project}:${releaseNode['sf_file_id']}'
        : '${config.project}:${publishedAt ?? fileName}';

    return RemoteUpdateInfo(
      releaseId: releaseId,
      platform: platform,
      version:
          _extractVersionFromFileName(fileName) ??
          _formatSourceForgeBuildLabel(publishedAt),
      buildNumber: '',
      downloadUrl: downloadUrl,
      mandatory: false,
      releaseNotes: const [],
      fileName: fileName,
      sourceName: 'SourceForge',
      publishedAt: publishedAt,
    );
  }

  static RemoteUpdateInfo? _parseSourceForgeFilesPage({
    required String html,
    required _SourceForgeProjectConfig config,
    required String platform,
  }) {
    final fileMatch = RegExp(
      'projects/${config.project}/files/([^"\']+?)/(?:download|stats/timeline)',
      caseSensitive: false,
    ).firstMatch(html);
    if (fileMatch == null) {
      return null;
    }

    final rawFileName = Uri.decodeComponent(fileMatch.group(1) ?? '').trim();
    if (rawFileName.isEmpty) {
      return null;
    }

    final dateMatch = RegExp(
      r'(\d{4}-\d{2}-\d{2})',
      caseSensitive: false,
    ).firstMatch(html);
    final publishedAt = dateMatch?.group(1);

    return RemoteUpdateInfo(
      releaseId: '${config.project}:${publishedAt ?? rawFileName}',
      platform: platform,
      version:
          _extractVersionFromFileName(rawFileName) ??
          _formatSourceForgeBuildLabel(publishedAt),
      buildNumber: '',
      downloadUrl:
          'https://sourceforge.net/projects/${config.project}/files/$rawFileName/download',
      mandatory: false,
      releaseNotes: const [],
      fileName: rawFileName,
      sourceName: 'SourceForge',
      publishedAt: publishedAt,
    );
  }

  static String? _normalizeSourceForgeDownloadUrl(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) {
      return null;
    }
    if (url.startsWith('http://')) {
      return 'https://${url.substring('http://'.length)}';
    }
    return url;
  }

  static String? _extractVersionFromFileName(String fileName) {
    final match = RegExp(r'(\d+\.\d+\.\d+(?:\.\d+)?)').firstMatch(fileName);
    return match?.group(1);
  }

  static String _formatSourceForgeBuildLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Latest build';
    }
    final normalized = value.trim().replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) {
      return 'Build $value';
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return 'Build ${parsed.year}-$month-$day $hour:$minute';
  }

  static String currentVersionOnly(String value) {
    return value.split('+').first.trim();
  }

  static int _compareBuildNumbers(String left, String right) {
    final leftNumber = int.tryParse(left) ?? 0;
    final rightNumber = int.tryParse(right) ?? 0;
    return leftNumber.compareTo(rightNumber);
  }

  static int _compareVersionStrings(String left, String right) {
    final leftParts = currentVersionOnly(left)
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final rightParts = currentVersionOnly(right)
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    final maxLength =
        leftParts.length > rightParts.length ? leftParts.length : rightParts.length;
    for (var index = 0; index < maxLength; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      final compare = leftValue.compareTo(rightValue);
      if (compare != 0) {
        return compare;
      }
    }
    return 0;
  }
}
