import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toothfile/update_install_types.dart';

Future<UpdateInstallResult> downloadAndInstallUpdate({
  required String platform,
  required String downloadUrl,
  String? fileName,
  UpdateProgressCallback? onProgress,
}) async {
  switch (platform) {
    case 'windows':
      return _downloadAndInstallWindows(
        downloadUrl: downloadUrl,
        fileName: fileName,
        onProgress: onProgress,
      );
    case 'android':
      return _downloadAndOpenFile(
        downloadUrl: downloadUrl,
        fileName: fileName,
        onProgress: onProgress,
        completedMessage:
            'The update was downloaded. Android will now open the package installer.',
      );
    case 'macos':
      return _downloadAndOpenFile(
        downloadUrl: downloadUrl,
        fileName: fileName,
        onProgress: onProgress,
        completedMessage:
            'The update zip was downloaded and will now open so you can replace the app.',
      );
    default:
      return const UpdateInstallResult(
        success: false,
        message: 'In-app installation is not supported on this platform.',
      );
  }
}

Future<void> exitForInstall() async {
  exit(0);
}

Future<UpdateInstallResult> _downloadAndInstallWindows({
  required String downloadUrl,
  String? fileName,
  UpdateProgressCallback? onProgress,
}) async {
  final installerFile = await _downloadUpdateFile(
    downloadUrl: downloadUrl,
    fileName: fileName,
    onProgress: onProgress,
  );
  if (installerFile == null) {
    return const UpdateInstallResult(
      success: false,
      message: 'Failed to download the Windows installer.',
    );
  }

  onProgress?.call(
    const UpdateInstallProgress(
      stage: UpdateInstallStage.launchingInstaller,
      message: 'Preparing installer and restart sequence...',
    ),
  );

  final scriptFile = File(
    '${installerFile.parent.path}${Platform.pathSeparator}install_toothfile_update.ps1',
  );
  final currentPid = pid;
  final currentExecutable = Platform.resolvedExecutable;
  final escapedInstaller = installerFile.path.replaceAll("'", "''");
  final escapedExecutable = currentExecutable.replaceAll("'", "''");

  await scriptFile.writeAsString('''
\$installer = '$escapedInstaller'
\$appExe = '$escapedExecutable'
\$pidToWait = $currentPid

while (Get-Process -Id \$pidToWait -ErrorAction SilentlyContinue) {
  Start-Sleep -Milliseconds 500
}

try {
  Start-Process -FilePath \$installer -ArgumentList @('/SP-', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS') -Wait
} catch {
  Start-Process -FilePath \$installer -Wait
}

Start-Sleep -Seconds 2

if (Test-Path \$appExe) {
  Start-Process -FilePath \$appExe
}
''');

  await Process.start(
    'powershell',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      scriptFile.path,
    ],
    mode: ProcessStartMode.detached,
  );

  onProgress?.call(
    const UpdateInstallProgress(
      stage: UpdateInstallStage.completed,
      message: 'Installer is ready. The app will close to finish the update.',
      progress: 1,
    ),
  );

  return const UpdateInstallResult(
    success: true,
    message: 'Installer downloaded. Closing the app to install the update.',
    appWillExit: true,
  );
}

Future<UpdateInstallResult> _downloadAndOpenFile({
  required String downloadUrl,
  String? fileName,
  UpdateProgressCallback? onProgress,
  required String completedMessage,
}) async {
  final downloadedFile = await _downloadUpdateFile(
    downloadUrl: downloadUrl,
    fileName: fileName,
    onProgress: onProgress,
  );
  if (downloadedFile == null) {
    return const UpdateInstallResult(
      success: false,
      message: 'Failed to download the update package.',
    );
  }

  onProgress?.call(
    const UpdateInstallProgress(
      stage: UpdateInstallStage.launchingInstaller,
      message: 'Opening the downloaded update package...',
    ),
  );

  final openResult = await OpenFilex.open(downloadedFile.path);
  if (openResult.type != ResultType.done) {
    return UpdateInstallResult(
      success: false,
      message: openResult.message.isNotEmpty
          ? openResult.message
          : 'Unable to open the downloaded update package.',
    );
  }

  onProgress?.call(
    const UpdateInstallProgress(
      stage: UpdateInstallStage.completed,
      message: 'The downloaded update package is now open.',
      progress: 1,
    ),
  );

  return UpdateInstallResult(success: true, message: completedMessage);
}

Future<File?> _downloadUpdateFile({
  required String downloadUrl,
  String? fileName,
  UpdateProgressCallback? onProgress,
}) async {
  try {
    final updatesDirectory = await _getUpdatesDirectory();
    final resolvedFileName = _resolveFileName(downloadUrl, fileName);
    final targetFile = File(
      '${updatesDirectory.path}${Platform.pathSeparator}$resolvedFileName',
    );

    onProgress?.call(
      const UpdateInstallProgress(
        stage: UpdateInstallStage.downloading,
        message: 'Downloading update...',
        progress: 0,
      ),
    );

    final request = http.Request('GET', Uri.parse(downloadUrl));
    final response = await http.Client().send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final sink = targetFile.openWrite();
    var receivedBytes = 0;
    final totalBytes = response.contentLength;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes != null && totalBytes > 0) {
        onProgress?.call(
          UpdateInstallProgress(
            stage: UpdateInstallStage.downloading,
            message: 'Downloading update...',
            progress: receivedBytes / totalBytes,
          ),
        );
      }
    }

    await sink.flush();
    await sink.close();
    return targetFile;
  } catch (_) {
    return null;
  }
}

Future<Directory> _getUpdatesDirectory() async {
  final baseDirectory = await getTemporaryDirectory();
  final updatesDirectory = Directory(
    '${baseDirectory.path}${Platform.pathSeparator}toothfile_updates',
  );
  if (!updatesDirectory.existsSync()) {
    await updatesDirectory.create(recursive: true);
  }
  return updatesDirectory;
}

String _resolveFileName(String downloadUrl, String? fileName) {
  final trimmedFileName = fileName?.trim();
  if (trimmedFileName != null && trimmedFileName.isNotEmpty) {
    return trimmedFileName;
  }

  final uri = Uri.tryParse(downloadUrl);
  final lastSegment = uri?.pathSegments.isNotEmpty == true
      ? uri!.pathSegments.last.trim()
      : '';
  if (lastSegment.isNotEmpty && lastSegment.toLowerCase() != 'download') {
    return lastSegment;
  }

  return 'toothfile_update.bin';
}
