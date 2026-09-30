import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_iptv/core/services/device_info_channel.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:path_provider/path_provider.dart';

/// A file chosen by [pickDeviceFile].
class PickedDeviceFile {
  const PickedDeviceFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Thrown when the device can't show any way to pick a file.
class DeviceFilePickerException implements Exception {
  const DeviceFilePickerException();
}

/// Lets the user choose a file on this device. Uses the system file picker
/// where there is one; on devices without one (many Google TV and Fire TV
/// models) it lists matching files from the app's own storage folder and
/// Downloads instead. Returns null if the user cancels.
Future<PickedDeviceFile?> pickDeviceFile(
  BuildContext context, {
  required String title,
  required List<String> extensions,
}) async {
  if (await hasDocumentPicker()) {
    final result =
        await FilePicker.pickFiles(type: FileType.any, withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return null;
    return PickedDeviceFile(file.name, file.bytes!);
  }
  final files = await _localFiles(extensions);
  if (!context.mounted) return null;
  final picked = await showDialog<File>(
    context: context,
    builder: (_) => _FileListDialog(title: title, files: files),
  );
  if (picked == null) return null;
  return PickedDeviceFile(
      picked.uri.pathSegments.last, await picked.readAsBytes());
}

/// Where the app looks when there's no system picker: its own storage
/// folder (which a file manager or `adb push` can write to), then Downloads.
Future<List<Directory>> fallbackFileFolders() async => [
      if (await getExternalStorageDirectory() case final d?) d,
      Directory('/storage/emulated/0/Download'),
    ];

Future<List<File>> _localFiles(List<String> extensions) async {
  final out = <File>[];
  for (final dir in await fallbackFileFolders()) {
    try {
      if (!dir.existsSync()) continue;
      for (final e in dir.listSync()) {
        if (e is File &&
            extensions.any((x) => e.path.toLowerCase().endsWith(x))) {
          out.add(e);
        }
      }
    } catch (_) {
      // Unreadable folder (storage permissions) — skip it.
    }
  }
  out.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  return out;
}

class _FileListDialog extends StatelessWidget {
  const _FileListDialog({required this.title, required this.files});

  final String title;
  final List<File> files;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 480,
        child: files.isEmpty
            ? Text(
                'No files found on this device. Copy the file to the '
                'Download folder, or to Android/data/com.openiptv.app/files, '
                'then try again.',
                style: theme.textTheme.bodyMedium!.copyWith(color: muted),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final (i, f) in files.indexed)
                    TvActivatable(
                      autofocus: i == 0,
                      onTap: () => Navigator.of(context).pop(f),
                      builder: (onTap) => ListTile(
                        leading: Icon(Icons.description_outlined, color: muted),
                        title: Text(f.uri.pathSegments.last,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_describe(f),
                            style: theme.textTheme.bodySmall),
                        onTap: onTap,
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TvActivatable(
          autofocus: files.isEmpty,
          onTap: () => Navigator.of(context).pop(),
          builder: (onTap) =>
              TextButton(onPressed: onTap, child: const Text('Cancel')),
        ),
      ],
    );
  }

  static String _describe(File f) {
    final kb = f.lengthSync() / 1024;
    final size = kb < 1024
        ? '${kb.toStringAsFixed(0)} KB'
        : '${(kb / 1024).toStringAsFixed(1)} MB';
    final m = f.statSync().modified;
    return '$size · ${m.year}-${m.month.toString().padLeft(2, '0')}-'
        '${m.day.toString().padLeft(2, '0')}';
  }
}
