import 'package:toothfile/update_install_types.dart';

Future<UpdateInstallResult> downloadAndInstallUpdate({
  required String platform,
  required String downloadUrl,
  String? fileName,
  UpdateProgressCallback? onProgress,
}) async {
  return const UpdateInstallResult(
    success: false,
    message: 'In-app installation is not supported on this platform.',
  );
}

Future<void> exitForInstall() async {}
