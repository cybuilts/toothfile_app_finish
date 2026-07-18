enum UpdateInstallStage {
  idle,
  downloading,
  launchingInstaller,
  completed,
  unsupported,
  failed,
}

class UpdateInstallProgress {
  const UpdateInstallProgress({
    required this.stage,
    required this.message,
    this.progress,
  });

  final UpdateInstallStage stage;
  final String message;
  final double? progress;
}

class UpdateInstallResult {
  const UpdateInstallResult({
    required this.success,
    required this.message,
    this.appWillExit = false,
  });

  final bool success;
  final String message;
  final bool appWillExit;
}

typedef UpdateProgressCallback = void Function(UpdateInstallProgress progress);
