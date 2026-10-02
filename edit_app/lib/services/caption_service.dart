import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/timeline_clip.dart';
import 'project_store.dart';

class CaptionCue {
  const CaptionCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
  final int startMs;
  final int endMs;
  final String text;
}

/// Genera caption dall’audio: Whisper CLI se disponibile, altrimenti chunk temporali.
class CaptionService {
  CaptionService(this._store, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final ProjectStore _store;
  final Uuid _uuid;

  Future<List<CaptionCue>> transcribeMediaFile({
    required String projectId,
    required String mediaFileName,
  }) async {
    final root = await _store.projectDir(projectId);
    final input = p.join(root.path, 'media', mediaFileName);
    if (!await File(input).exists()) {
      throw StateError('File audio/video non trovato');
    }

    final work = Directory(p.join(root.path, 'cache', 'stt'));
    await work.create(recursive: true);
    final wav = p.join(work.path, 'speech.wav');

    final ffmpeg = await _resolveBin(const [
      'ffmpeg',
      '/opt/homebrew/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
    ]);
    if (ffmpeg == null) {
      throw StateError('FFmpeg richiesto per estrarre l’audio');
    }

    await _run(ffmpeg, [
      '-y',
      '-i',
      input,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '16000',
      wav,
    ]);

    final whisper = await _resolveBin(const [
      'whisper-cli',
      'whisper',
      '/opt/homebrew/bin/whisper-cli',
      '/opt/homebrew/bin/whisper',
    ]);

    if (whisper != null) {
      try {
        final cues = await _runWhisper(whisper, wav, work.path);
        if (cues.isNotEmpty) return cues;
      } catch (_) {}
    }

    // Fallback: spezza in segmenti da ~3s (l’utente edita il testo).
    final durationMs = await _probeDurationMs(ffmpeg, wav) ?? 12000;
    return _chunkFallback(durationMs);
  }

  List<TimelineClip> cuesToClips(List<CaptionCue> cues) {
    return cues
        .map(
          (c) => TimelineClip(
            id: _uuid.v4(),
            mediaId: '',
            sourceStartMs: 0,
            sourceEndMs: (c.endMs - c.startMs).clamp(400, 1 << 30),
            timelineStartMs: c.startMs,
            trackKind: TrackKind.text,
            trackIndex: 0,
            text: c.text,
            textMotion: TextMotion.fadeIn,
          ),
        )
        .toList();
  }

  List<CaptionCue> _chunkFallback(int durationMs) {
    const step = 3000;
    final out = <CaptionCue>[];
    for (var t = 0; t < durationMs; t += step) {
      final end = (t + step).clamp(0, durationMs);
      if (end - t < 400) break;
      out.add(
        CaptionCue(
          startMs: t,
          endMs: end,
          text: '… (modifica sottotitolo)',
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        const CaptionCue(
          startMs: 0,
          endMs: 3000,
          text: '… (modifica sottotitolo)',
        ),
      );
    }
    return out;
  }

  Future<List<CaptionCue>> _runWhisper(
    String bin,
    String wav,
    String workDir,
  ) async {
    // whisper.cpp: whisper-cli -f file -l it -osrt -of out
    final outBase = p.join(workDir, 'out');
    final r = await Process.run(bin, [
      '-f',
      wav,
      '-l',
      'it',
      '-osrt',
      '-of',
      outBase,
    ]);
    if (r.exitCode != 0) {
      // openai-whisper style: whisper file --language it --output_format srt
      final r2 = await Process.run(bin, [
        wav,
        '--language',
        'it',
        '--output_format',
        'srt',
        '--output_dir',
        workDir,
      ]);
      if (r2.exitCode != 0) {
        throw StateError('Whisper fallito');
      }
    }

    final srtCandidates = [
      File('$outBase.srt'),
      File(p.join(workDir, '${p.basenameWithoutExtension(wav)}.srt')),
    ];
    for (final f in srtCandidates) {
      if (await f.exists()) {
        return _parseSrt(await f.readAsString());
      }
    }
    // cerca qualsiasi .srt in workDir
    await for (final e in Directory(workDir).list()) {
      if (e is File && e.path.endsWith('.srt')) {
        return _parseSrt(await e.readAsString());
      }
    }
    return [];
  }

  List<CaptionCue> _parseSrt(String raw) {
    final blocks = raw.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
    final cues = <CaptionCue>[];
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;
      final timeLine = lines.firstWhere(
        (l) => l.contains('-->'),
        orElse: () => '',
      );
      if (timeLine.isEmpty) continue;
      final parts = timeLine.split('-->');
      if (parts.length != 2) continue;
      final start = _parseTs(parts[0].trim());
      final end = _parseTs(parts[1].trim());
      final textLines = lines.skipWhile((l) => !l.contains('-->')).skip(1);
      final text = textLines.join(' ').trim();
      if (text.isEmpty) continue;
      cues.add(CaptionCue(startMs: start, endMs: end, text: text));
    }
    return cues;
  }

  int _parseTs(String ts) {
    // 00:00:01,000 or 00:00:01.000
    final clean = ts.replaceAll(',', '.');
    final m = RegExp(r'(\d+):(\d+):(\d+)[\.:](\d+)').firstMatch(clean);
    if (m == null) return 0;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final s = int.parse(m.group(3)!);
    final ms = int.parse(m.group(4)!.padRight(3, '0').substring(0, 3));
    return ((h * 3600 + min * 60 + s) * 1000) + ms;
  }

  Future<int?> _probeDurationMs(String ffmpeg, String path) async {
    final r = await Process.run(ffmpeg, [
      '-i',
      path,
      '-f',
      'null',
      '-',
    ], stderrEncoding: utf8);
    final err = r.stderr as String;
    final m = RegExp(r'Duration: (\d+):(\d+):(\d+\.\d+)').firstMatch(err);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final sec = double.parse(m.group(3)!);
    return ((h * 3600 + min * 60 + sec) * 1000).round();
  }

  Future<String?> _resolveBin(List<String> candidates) async {
    for (final c in candidates) {
      try {
        final r = await Process.run(c, ['-h']);
        if (r.exitCode == 0 || r.exitCode == 1) return c;
      } catch (_) {
        try {
          final r = await Process.run(c, ['--help']);
          if (r.exitCode == 0 || r.exitCode == 1) return c;
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _run(String bin, List<String> args) async {
    final r =
        await Process.run(bin, args, stdoutEncoding: utf8, stderrEncoding: utf8);
    if (r.exitCode != 0) {
      throw StateError((r.stderr as String).split('\n').last);
    }
  }
}
