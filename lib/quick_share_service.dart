import 'dart:io';
import 'package:flutter/foundation.dart';

class QuickShareService {
  static final ValueNotifier<List<String>> _pendingFilePaths =
      ValueNotifier<List<String>>([]);

  static bool get hasPendingFiles => _pendingFilePaths.value.isNotEmpty;

  static void addPendingFiles(List<String> rawPaths) {
    final normalized = rawPaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .where((path) => File(path).existsSync())
        .toSet()
        .toList();
    if (normalized.isEmpty) {
      return;
    }
    final merged = <String>{..._pendingFilePaths.value, ...normalized}.toList();
    _pendingFilePaths.value = merged;
  }

  static List<String> consumePendingFiles() {
    final files = List<String>.from(_pendingFilePaths.value);
    _pendingFilePaths.value = [];
    return files;
  }
}
