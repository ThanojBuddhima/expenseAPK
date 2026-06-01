import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<AppReleaseInfo?> checkForUpdate() async {
    if (!isSupported) {
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

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
      final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latestVersion.isEmpty || !_isNewer(latestVersion, currentVersion)) {
        return null;
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

  bool _isNewer(String latest, String current) {
    final latestParts = _parseVersion(latest);
    final currentParts = _parseVersion(current);
    final length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;
    for (var i = 0; i < length; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) {
        return true;
      }
      if (l < c) {
        return false;
      }
    }
    return false;
  }

  List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
