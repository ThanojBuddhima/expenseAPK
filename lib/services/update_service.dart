import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_preferences.dart';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String version;
  final String downloadUrl;
  final String releaseNotes;
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _owner = 'ThanojBuddhima';
  static const _repo = 'expenseAPK';
  static const _apkName = 'app-release.apk';

  bool _silentCheckRanThisSession = false;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Automatic startup check runs at most once per app process.
  bool get silentCheckRanThisSession => _silentCheckRanThisSession;

  void markSilentCheckRan() {
    _silentCheckRanThisSession = true;
  }

  /// Returns release info only when GitHub latest is strictly newer than the
  /// installed app version.
  Future<AppReleaseInfo?> checkForUpdate({
    bool respectDismissed = false,
  }) async {
    if (!isSupported) {
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();
      final currentBuild = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

      final uri = Uri.parse(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
      );
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/vnd.github+json'},
      );
      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final latestVersion = _normalizeVersionTag(tag);
      if (latestVersion.isEmpty) {
        return null;
      }

      if (!_isStrictlyNewer(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      )) {
        return null;
      }

      if (respectDismissed) {
        final dismissed = await AppPreferences.instance.dismissedUpdateVersion;
        if (dismissed != null && dismissed == latestVersion) {
          return null;
        }
      }

      final assets = json['assets'] as List<dynamic>? ?? [];
      String? downloadUrl;
      for (final asset in assets) {
        if (asset is Map<String, dynamic> &&
            asset['name'] == _apkName &&
            asset['browser_download_url'] is String) {
          downloadUrl = asset['browser_download_url'] as String;
          break;
        }
      }
      if (downloadUrl == null) {
        return null;
      }

      final notes = (json['body'] as String?)?.trim() ?? '';
      return AppReleaseInfo(
        version: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: notes.isEmpty ? 'Bug fixes and improvements.' : notes,
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('UpdateService.checkForUpdate: $error');
      }
      return null;
    }
  }

  Future<void> dismissVersion(String version) async {
    await AppPreferences.instance.setDismissedUpdateVersion(version);
  }

  Future<File> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Download failed (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final bytes = <int>[];

    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(received / total);
      }
    }

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, _apkName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<OpenResult> installApk(File apkFile) async {
    return OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );
  }

  String _normalizeVersionTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  /// True only when [latestVersion] is greater than the installed version.
  bool _isStrictlyNewer({
    required String latestVersion,
    required String currentVersion,
    required int currentBuild,
  }) {
    final comparison = _compareSemver(latestVersion, currentVersion);
    if (comparison > 0) {
      return true;
    }
    if (comparison < 0) {
      return false;
    }
    // Same semver as release tag — treat as up to date (build number is local).
    return false;
  }

  /// Negative if a < b, zero if equal, positive if a > b.
  int _compareSemver(String a, String b) {
    final aParts = _parseVersion(a);
    final bParts = _parseVersion(b);
    final length = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;
    for (var i = 0; i < length; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) {
        return av.compareTo(bv);
      }
    }
    return 0;
  }

  List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
