import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/project.dart';
import 'project_store.dart';

/// Riduzione rumore audio via FFmpeg (afftdn / highpass+lowpass), file su disco.
class AudioDenoiseService {
  AudioDenoiseService(this._store, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final ProjectStore _store;
  final Uuid _uuid;

  Future<MediaRef> denoise({
    required EditProject project,
    required MediaRef source,
  }) async {
    if (source.kind != MediaKind.audio && source.kind != MediaKind.video) {
      throw StateError('Seleziona un clip audio o video');
    }

    final ffmpeg = await _resolveFfmpeg();
    if (ffmpeg == null) {
      throw StateError('FFmpeg non trovato');
    }

    final root = await _store.projectDir(project.id);
    final input = p.join(root.path, 'media', source.fileName);
    if (!await File(input).exists()) {
      throw StateError('Media non trovato');
    }

    final outId = _uuid.v4();
    final outName = source.kind == MediaKind.video
        ? '$outId.mp4'
        : '$outId.m4a';
    final output = p.join(root.path, 'media', outName);

    // afftdn: denoise spettrale leggero; fallback highpass se non supportato.
    try {
      if (source.kind == MediaKind.video) {
        await _run(ffmpeg, [
          '-y',
          '-i',
          input,
          '-af',
          'highpass=f=80,afftdn=nr=12:nf=-25',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          '-b:a',
          '192k',
          output,
        ]);
      } else {
        await _run(ffmpeg, [
          '-y',
          '-i',
          input,
          '-af',
          'highpass=f=80,afftdn=nr=12:nf=-25',
          '-c:a',
          'aac',
          '-b:a',
          '192k',
          output,
        ]);
      }
    } catch (_) {
      if (source.kind == MediaKind.video) {
        await _run(ffmpeg, [
          '-y',
          '-i',
          input,
          '-af',
          'highpass=f=100,lowpass=f=8000,volume=1.05',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          output,
        ]);
      } else {
        await _run(ffmpeg, [
          '-y',
          '-i',
          input,
          '-af',
          'highpass=f=100,lowpass=f=8000,volume=1.05',
          '-c:a',
          'aac',
          output,
        ]);
      }
    }

    if (!await File(output).exists()) {
      throw StateError('Output denoise non creato');
    }

    return MediaRef(
      id: outId,
      fileName: outName,
      kind: source.kind,
      durationMs: source.durationMs,
      displayName: '${source.label} (pulito)',
    );
  }

  Future<String?> _resolveFfmpeg() async {
    for (final c in [
      'ffmpeg',
      '/opt/homebrew/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
    ]) {
      try {
        final r = await Process.run(c, ['-version']);
        if (r.exitCode == 0) return c;
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
