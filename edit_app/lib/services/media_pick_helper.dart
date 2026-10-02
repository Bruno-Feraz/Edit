import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/editor_controller.dart';

/// Estensioni foto / video supportate dall’import.
const kMediaImportExtensions = <String>[
  'mp4',
  'mov',
  'm4v',
  'webm',
  'mkv',
  'avi',
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'heic',
];

/// Apre il file picker e importa foto/video. Gestisce entitlement macOS.
Future<void> pickAndImportPhotoVideo(
  BuildContext context,
  EditorController controller,
) async {
  try {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: kMediaImportExtensions,
        allowMultiple: false,
        withData: false,
      );
    } on PlatformException {
      result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    }
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;
    await controller.importAny(path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import completato')),
    );
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    final msg = (e.code == 'ENTITLEMENT_NOT_FOUND')
        ? 'Permesso file mancante. Chiudi e riapri Edit (serve rebuild macOS).'
        : 'Import non riuscito: ${e.message ?? e.code}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// Import solo audio.
Future<void> pickAndImportAudio(
  BuildContext context,
  EditorController controller,
) async {
  try {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );
    } on PlatformException {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'],
        allowMultiple: false,
        withData: false,
      );
    }
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;
    await controller.importAudio(path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio importato')),
    );
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    final msg = (e.code == 'ENTITLEMENT_NOT_FOUND')
        ? 'Permesso file mancante. Chiudi e riapri Edit (serve rebuild macOS).'
        : 'Import audio non riuscito: ${e.message ?? e.code}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

extension on List<PlatformFile> {
  PlatformFile? get singleOrNull => isEmpty ? null : single;
}
