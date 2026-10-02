import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/project.dart';
import 'project_store.dart';

/// Rimuove sfondo via CLI locale (rembg / backgroundremover), stream su disco.
class BackgroundRemoveService {
  BackgroundRemoveService(this._store, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final ProjectStore _store;
  final Uuid _uuid;

  Future<MediaRef> removeBackground({
    required EditProject project,
    required MediaRef source,
  }) async {
    final root = await _store.projectDir(project.id);
    final input = p.join(root.path, 'media', source.fileName);
    if (!await File(input).exists()) {
      throw StateError('Media non trovato');
    }

    final tool = await _resolveTool();
    if (tool == null) {
      throw StateError(
        'Nessun tool rembg trovato. Installa: pip install rembg  oppure  pip install backgroundremover',
      );
    }

    final outId = _uuid.v4();
    final outName = source.kind == MediaKind.video
        ? '$outId.webm'
        : '$outId.png';
    final output = p.join(root.path, 'media', outName);

    if (tool.name == 'rembg') {
      await _run(tool.path, ['i', input, output]);
    } else {
      // backgroundremover
      if (source.kind == MediaKind.video) {
        await _run(tool.path, [
          '-i',
          input,
          '-tv',
          '-o',
          output,
        ]);
      } else {
        await _run(tool.path, ['-i', input, '-o', output]);
      }
    }

    if (!await File(output).exists()) {
      throw StateError('Output rembg non creato');
    }

    return MediaRef(
      id: outId,
      fileName: outName,
      kind: source.kind == MediaKind.video ? MediaKind.video : MediaKind.image,
      durationMs: source.durationMs,
      displayName: '${source.label} (no bg)',
    );
  }

  Future<_Tool?> _resolveTool() async {
    for (final c in ['rembg', '/opt/homebrew/bin/rembg']) {
      try {
        final r = await Process.run(c, ['--help']);
        if (r.exitCode == 0 || (r.stderr as String).isNotEmpty) {
          return _Tool('rembg', c);
        }
      } catch (_) {}
    }
    for (final c in [
      'backgroundremover',
      '/opt/homebrew/bin/backgroundremover',
    ]) {
      try {
        final r = await Process.run(c, ['--help']);
        if (r.exitCode == 0 || r.exitCode == 1) {
          return _Tool('backgroundremover', c);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _run(String bin, List<String> args) async {
    final r =
        await Process.run(bin, args, stdoutEncoding: utf8, stderrEncoding: utf8);
    if (r.exitCode != 0) {
      final err = (r.stderr as String).trim();
      throw StateError(err.isEmpty ? 'exit ${r.exitCode}' : err.split('\n').last);
    }
  }
}

class _Tool {
  const _Tool(this.name, this.path);
  final String name;
  final String path;
}
