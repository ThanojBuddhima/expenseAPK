import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../app_theme.dart';
import '../services/update_service.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppReleaseInfo release,
  bool mandatory = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !mandatory,
    builder: (dialogContext) {
      return _AppUpdateDialog(release: release);
    },
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.release});

  final AppReleaseInfo release;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });

    try {
      final file = await UpdateService.instance.downloadApk(
        widget.release.downloadUrl,
        onProgress: (value) {
          if (mounted) {
            setState(() => _progress = value);
          }
        },
      );

      if (!mounted) {
        return;
      }

      final result = await UpdateService.instance.installApk(file);
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _error = result.message.isNotEmpty
              ? result.message
              : 'Could not open the installer. Tap the downloaded APK in your '
                  'file manager if needed.';
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;

    return AlertDialog(
      title: const Text('Update available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${release.version} is available.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(release.releaseNotes),
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 8),
              Text(
                _progress > 0
                    ? '${(_progress * 100).toStringAsFixed(0)}% downloaded'
                    : 'Downloading…',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.expenseTint),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Android will ask you to confirm installation. The app cannot '
              'install updates silently.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        if (!_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
        FilledButton(
          onPressed: _downloading ? null : _downloadAndInstall,
          child: Text(_downloading ? 'Downloading…' : 'Download & install'),
        ),
      ],
    );
  }
}

Future<void> checkAndPromptForUpdate(
  BuildContext context, {
  bool silentIfLatest = true,
}) async {
  if (!UpdateService.instance.isSupported) {
    if (!silentIfLatest && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('In-app updates are only available on Android.'),
        ),
      );
    }
    return;
  }

  try {
    final release = await UpdateService.instance.checkForUpdate();
    if (!context.mounted) {
      return;
    }
    if (release == null) {
      if (!silentIfLatest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are on the latest version.')),
        );
      }
      return;
    }
    await showAppUpdateDialog(context, release: release);
  } on Object catch (error) {
    if (!silentIfLatest && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update check failed: $error')),
      );
    }
  }
}
