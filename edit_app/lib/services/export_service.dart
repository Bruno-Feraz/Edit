import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/project.dart';
import '../models/social_export_preset.dart';
import '../models/timeline_clip.dart';
import 'project_store.dart';

class ExportResult {
  const ExportResult({required this.outputPath});
  final String outputPath;
}

class ExportException implements Exception {
  ExportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Export MP4 via FFmpeg (processo esterno → non tiene frame in RAM Dart).
class ExportService {
  ExportService(this._store);

  final ProjectStore _store;

  Future<ExportResult> exportProject(
    EditProject project, {
    SocialExportPreset? social,
  }) async {
    final ffmpeg = await _resolveFfmpeg();
    if (ffmpeg == null) {
      throw ExportException(
        'FFmpeg non trovato. Su Mac: brew install ffmpeg',
      );
    }

    final projectRoot = await _store.projectDir(project.id);
    var videoClips = [...project.timeline.clipsOn(TrackKind.video, 0)]
      ..sort((a, b) => a.timelineStartMs.compareTo(b.timelineStartMs));
    if (videoClips.isEmpty) {
      videoClips = [...project.timeline.videoClips]
        ..sort((a, b) => a.timelineStartMs.compareTo(b.timelineStartMs));
    }
    if (videoClips.isEmpty) {
      throw ExportException('Nessun clip video da esportare');
    }

    final work = Directory(p.join(projectRoot.path, 'cache', 'export'));
    if (await work.exists()) await work.delete(recursive: true);
    await work.create(recursive: true);

    final videoBase = await _buildVideoBase(
      ffmpeg: ffmpeg,
      project: project,
      projectRoot: projectRoot,
      work: work,
      clips: videoClips,
    );

    final outDir = Directory(p.join(projectRoot.path, 'exports'));
    await outDir.create(recursive: true);
    final safeName = project.name.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    final presetTag = social?.name ?? 'custom';
    final outPath = p.join(
      outDir.path,
      '${safeName.isEmpty ? 'edit' : safeName}_${presetTag}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final audioClips = [...project.timeline.audioClips]
      ..sort((a, b) => a.timelineStartMs.compareTo(b.timelineStartMs));
    final captions = project.timeline.textClips
        .where((c) => (c.text ?? '').trim().isNotEmpty)
        .toList();

    final needsMix = audioClips.isNotEmpty ||
        captions.isNotEmpty ||
        videoClips.any((c) => c.volume < 0.999);

    var current = videoBase;
    if (needsMix) {
      final mixed = p.join(work.path, 'mixed.mp4');
      await _mixAudioAndCaptions(
        ffmpeg: ffmpeg,
        project: project,
        projectRoot: projectRoot,
        work: work,
        videoBase: videoBase,
        audioClips: audioClips,
        captions: captions,
        outPath: mixed,
      );
      current = mixed;
    }

    if (social != null) {
      await _scaleToSocial(
        ffmpeg: ffmpeg,
        input: current,
        outPath: outPath,
        preset: social,
      );
    } else if (current != outPath) {
      await File(current).copy(outPath);
    }

    try {
      await work.delete(recursive: true);
    } catch (_) {}

    return ExportResult(outputPath: outPath);
  }

  Future<void> _scaleToSocial({
    required String ffmpeg,
    required String input,
    required String outPath,
    required SocialExportPreset preset,
  }) async {
    final w = preset.width;
    final h = preset.height;
    final vf =
        'scale=$w:$h:force_original_aspect_ratio=decrease,'
        'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black,'
        'setsar=1';
    await _run(ffmpeg, [
      '-y',
      '-i',
      input,
      '-vf',
      vf,
      '-r',
      '30',
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      '20',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-movflags',
      '+faststart',
      outPath,
    ]);
  }

  Future<String> _buildVideoBase({
    required String ffmpeg,
    required EditProject project,
    required Directory projectRoot,
    required Directory work,
    required List<TimelineClip> clips,
  }) async {
    final segmentPaths = <String>[];
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final media = project.mediaById(clip.mediaId);
      if (media == null) {
        throw ExportException('Media mancante per clip ${clip.id}');
      }
      if (media.kind == MediaKind.image) {
        throw ExportException(
          'Export immagini in timeline: in arrivo. Usa clip video per ora.',
        );
      }
      final input = p.join(projectRoot.path, 'media', media.fileName);
      final segment = p.join(work.path, 'seg_$i.mp4');
      final args = <String>[
        '-y',
        '-ss',
        _sec(clip.sourceStartMs),
        '-to',
        _sec(clip.sourceEndMs),
        '-i',
        input,
      ];
      if (clip.hasEnhance) {
        final b = clip.brightness.toStringAsFixed(3);
        final c = clip.contrast.toStringAsFixed(3);
        final s = clip.saturation.toStringAsFixed(3);
        args.addAll([
          '-vf',
          'eq=brightness=$b:contrast=$c:saturation=$s',
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-crf',
          '20',
          '-c:a',
          'aac',
        ]);
      } else {
        args.addAll([
          '-c',
          'copy',
          '-avoid_negative_ts',
          'make_zero',
        ]);
      }
      args.add(segment);
      await _run(ffmpeg, args);
      segmentPaths.add(segment);
    }

    final videoBase = p.join(work.path, 'video_base.mp4');
    if (segmentPaths.length == 1) {
      await File(segmentPaths.first).copy(videoBase);
    } else {
      final listFile = File(p.join(work.path, 'concat.txt'));
      final buf = StringBuffer();
      for (final seg in segmentPaths) {
        buf.writeln("file '${seg.replaceAll("'", "'\\''")}'");
      }
      await listFile.writeAsString(buf.toString());
      await _run(ffmpeg, [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-c',
        'copy',
        videoBase,
      ]);
    }
    return videoBase;
  }

  Future<void> _mixAudioAndCaptions({
    required String ffmpeg,
    required EditProject project,
    required Directory projectRoot,
    required Directory work,
    required String videoBase,
    required List<TimelineClip> audioClips,
    required List<TimelineClip> captions,
    required String outPath,
  }) async {
    final args = <String>['-y', '-i', videoBase];
    for (final clip in audioClips) {
      final media = project.mediaById(clip.mediaId);
      if (media == null) continue;
      args.addAll(['-i', p.join(projectRoot.path, 'media', media.fileName)]);
    }

    final filters = <String>[];
    final mixInputs = <String>[];

    // Audio del video (se presente) a volume medio dei clip video ~1
    filters.add('[0:a]volume=1.0[a0]');
    mixInputs.add('[a0]');

    for (var i = 0; i < audioClips.length; i++) {
      final clip = audioClips[i];
      final inputIdx = i + 1;
      final delay = clip.timelineStartMs;
      final vol = clip.volume.clamp(0.0, 1.0);
      // adelay in ms for each channel
      filters.add(
        '[$inputIdx:a]atrim=start=${_sec(clip.sourceStartMs)}:end=${_sec(clip.sourceEndMs)},'
        'asetpts=PTS-STARTPTS,'
        'adelay=$delay|$delay,'
        'volume=$vol[a$inputIdx]',
      );
      mixInputs.add('[a$inputIdx]');
    }

    final n = mixInputs.length;
    filters.add(
      '${mixInputs.join('')}amix=inputs=$n:duration=first:dropout_transition=0[aout]',
    );

    String videoMap = '0:v';
    if (captions.isNotEmpty) {
      final draws = <String>[];
      for (final c in captions) {
        final t = _escapeDrawText(c.text ?? '');
        final start = (c.timelineStartMs / 1000.0).toStringAsFixed(3);
        final end = (c.timelineEndMs / 1000.0).toStringAsFixed(3);
        draws.add(
          "drawtext=text='$t':fontsize=28:fontcolor=white:borderw=2:"
          "bordercolor=black:x=(w-text_w)/2:y=h-100:"
          "enable='between(t\\,$start\\,$end)'",
        );
      }
      filters.add('[0:v]${draws.join(',')}[vout]');
      videoMap = '[vout]';
    }

    final filterComplex = filters.join(';');
    args.addAll([
      '-filter_complex',
      filterComplex,
      '-map',
      videoMap,
      '-map',
      '[aout]',
      '-c:v',
      captions.isEmpty ? 'copy' : 'libx264',
      if (captions.isNotEmpty) ...['-preset', 'veryfast', '-crf', '20'],
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-shortest',
      outPath,
    ]);

    try {
      await _run(ffmpeg, args);
    } catch (_) {
      // Fallback: video senza audio track originale (anull)
      await _mixAudioFallback(
        ffmpeg: ffmpeg,
        project: project,
        projectRoot: projectRoot,
        videoBase: videoBase,
        audioClips: audioClips,
        captions: captions,
        outPath: outPath,
      );
    }
  }

  /// Se il video non ha stream audio, crea mix solo dalle tracce A*.
  Future<void> _mixAudioFallback({
    required String ffmpeg,
    required EditProject project,
    required Directory projectRoot,
    required String videoBase,
    required List<TimelineClip> audioClips,
    required List<TimelineClip> captions,
    required String outPath,
  }) async {
    if (audioClips.isEmpty && captions.isEmpty) {
      await File(videoBase).copy(outPath);
      return;
    }

    final args = <String>['-y', '-i', videoBase];
    for (final clip in audioClips) {
      final media = project.mediaById(clip.mediaId);
      if (media == null) continue;
      args.addAll(['-i', p.join(projectRoot.path, 'media', media.fileName)]);
    }

    final filters = <String>[];
    final mixInputs = <String>[];

    if (audioClips.isEmpty) {
      filters.add('anullsrc=channel_layout=stereo:sample_rate=44100[aout]');
    } else {
      for (var i = 0; i < audioClips.length; i++) {
        final clip = audioClips[i];
        final inputIdx = i + 1;
        final delay = clip.timelineStartMs;
        final vol = clip.volume.clamp(0.0, 1.0);
        filters.add(
          '[$inputIdx:a]atrim=start=${_sec(clip.sourceStartMs)}:end=${_sec(clip.sourceEndMs)},'
          'asetpts=PTS-STARTPTS,'
          'adelay=$delay|$delay,'
          'volume=$vol[a$inputIdx]',
        );
        mixInputs.add('[a$inputIdx]');
      }
      filters.add(
        '${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest:dropout_transition=0[aout]',
      );
    }

    String videoMap = '0:v';
    if (captions.isNotEmpty) {
      final draws = <String>[];
      for (final c in captions) {
        final t = _escapeDrawText(c.text ?? '');
        final start = (c.timelineStartMs / 1000.0).toStringAsFixed(3);
        final end = (c.timelineEndMs / 1000.0).toStringAsFixed(3);
        draws.add(
          "drawtext=text='$t':fontsize=28:fontcolor=white:borderw=2:"
          "bordercolor=black:x=(w-text_w)/2:y=h-100:"
          "enable='between(t\\,$start\\,$end)'",
        );
      }
      filters.add('[0:v]${draws.join(',')}[vout]');
      videoMap = '[vout]';
    }

    args.addAll([
      '-filter_complex',
      filters.join(';'),
      '-map',
      videoMap,
      '-map',
      '[aout]',
      '-c:v',
      captions.isEmpty ? 'copy' : 'libx264',
      if (captions.isNotEmpty) ...['-preset', 'veryfast', '-crf', '20'],
      '-c:a',
      'aac',
      '-shortest',
      outPath,
    ]);
    await _run(ffmpeg, args);
  }

  String _escapeDrawText(String raw) {
    return raw
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll(':', '\\:')
        .replaceAll('%', '\\%');
  }

  String _sec(int ms) => (ms / 1000.0).toStringAsFixed(3);

  Future<String?> _resolveFfmpeg() async {
    const candidates = [
      'ffmpeg',
      '/opt/homebrew/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
    ];
    for (final c in candidates) {
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
      throw ExportException(
        err.isEmpty ? 'FFmpeg exit ${r.exitCode}' : err.split('\n').last,
      );
    }
  }
}
