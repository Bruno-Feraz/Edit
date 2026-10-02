import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../models/project.dart';
import '../models/timeline_clip.dart';
import 'project_store.dart';

/// Import media: copia in stream (niente `readAsBytes` su file grandi).
class MediaImportService {
  MediaImportService(this._store, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final ProjectStore _store;
  final Uuid _uuid;

  static const _videoExt = {'.mp4', '.mov', '.m4v', '.webm', '.mkv'};
  static const _imageExt = {'.png', '.jpg', '.jpeg', '.webp'};
  static const _audioExt = {'.mp3', '.wav', '.m4a', '.aac', '.ogg'};

  Future<MediaRef> importFile({
    required EditProject project,
    required String sourcePath,
    TrackKind trackKind = TrackKind.video,
    int trackIndex = 0,
    int? imageDurationMs,
  }) async {
    final ext = p.extension(sourcePath).toLowerCase();
    final kind = _kindForExt(ext);
    if (kind == null) {
      throw UnsupportedError('Formato non supportato: $ext');
    }

    final id = _uuid.v4();
    final fileName = '$id$ext';
    final dir = await _store.projectDir(project.id);
    final dest = File(p.join(dir.path, 'media', fileName));
    await dest.parent.create(recursive: true);
    await File(sourcePath).openRead().pipe(dest.openWrite());

    final displayName = p.basename(sourcePath);
    int? durationMs;
    if (kind == MediaKind.video) {
      durationMs = await _probeDurationMs(dest.path);
    } else if (kind == MediaKind.image) {
      durationMs = imageDurationMs ?? 3000;
    } else {
      durationMs = await _probeDurationMs(dest.path) ?? 5000;
    }

    final ref = MediaRef(
      id: id,
      fileName: fileName,
      kind: kind,
      durationMs: durationMs,
      displayName: displayName,
    );
    project.media = [...project.media, ref];

    final resolvedKind =
        kind == MediaKind.audio ? TrackKind.audio : trackKind;
    final idx = resolvedKind == TrackKind.audio
        ? trackIndex.clamp(0, project.timeline.audioTrackCount - 1)
        : trackIndex.clamp(0, project.timeline.videoTrackCount - 1);

    final start = _endOfTrack(project, resolvedKind, idx);
    project.timeline.clips.add(
      TimelineClip(
        id: _uuid.v4(),
        mediaId: id,
        sourceStartMs: 0,
        sourceEndMs: durationMs ?? 3000,
        timelineStartMs: start,
        trackKind: resolvedKind,
        trackIndex: idx,
      ),
    );

    await _store.saveProject(project);
    return ref;
  }

  /// Solo in libreria, senza mettere sulla timeline.
  Future<MediaRef> importToLibrary({
    required EditProject project,
    required String sourcePath,
  }) async {
    final ext = p.extension(sourcePath).toLowerCase();
    final kind = _kindForExt(ext);
    if (kind == null) {
      throw UnsupportedError('Formato non supportato: $ext');
    }
    final id = _uuid.v4();
    final fileName = '$id$ext';
    final dir = await _store.projectDir(project.id);
    final dest = File(p.join(dir.path, 'media', fileName));
    await dest.parent.create(recursive: true);
    await File(sourcePath).openRead().pipe(dest.openWrite());

    int? durationMs;
    if (kind == MediaKind.video || kind == MediaKind.audio) {
      durationMs = await _probeDurationMs(dest.path);
    } else {
      durationMs = 3000;
    }

    final ref = MediaRef(
      id: id,
      fileName: fileName,
      kind: kind,
      durationMs: durationMs,
      displayName: p.basename(sourcePath),
    );
    project.media = [...project.media, ref];
    await _store.saveProject(project);
    return ref;
  }

  Future<MediaRef> importVoiceFile({
    required EditProject project,
    required String sourcePath,
    required int durationMs,
    int trackIndex = 0,
    int timelineStartMs = 0,
  }) async {
    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = ext.isEmpty ? '.m4a' : ext;
    final id = _uuid.v4();
    final fileName = '$id$safeExt';
    final dir = await _store.projectDir(project.id);
    final dest = File(p.join(dir.path, 'media', fileName));
    await dest.parent.create(recursive: true);
    await File(sourcePath).openRead().pipe(dest.openWrite());

    final ref = MediaRef(
      id: id,
      fileName: fileName,
      kind: MediaKind.audio,
      durationMs: durationMs,
      displayName: 'Voice-over',
    );
    project.media = [...project.media, ref];

    final idx = trackIndex.clamp(0, project.timeline.audioTrackCount - 1);
    project.timeline.clips.add(
      TimelineClip(
        id: _uuid.v4(),
        mediaId: id,
        sourceStartMs: 0,
        sourceEndMs: durationMs,
        timelineStartMs: timelineStartMs,
        trackKind: TrackKind.audio,
        trackIndex: idx,
        volume: 1.0,
      ),
    );
    await _store.saveProject(project);
    return ref;
  }

  Future<MediaRef> importVideoFile({
    required EditProject project,
    required String sourcePath,
    int trackIndex = 0,
  }) {
    return importFile(
      project: project,
      sourcePath: sourcePath,
      trackKind: TrackKind.video,
      trackIndex: trackIndex,
    );
  }

  MediaKind? _kindForExt(String ext) {
    if (_videoExt.contains(ext)) return MediaKind.video;
    if (_imageExt.contains(ext)) return MediaKind.image;
    if (_audioExt.contains(ext)) return MediaKind.audio;
    return null;
  }

  int _endOfTrack(EditProject project, TrackKind kind, int index) {
    final track = project.timeline.clipsOn(kind, index);
    if (track.isEmpty) return 0;
    var maxEnd = 0;
    for (final c in track) {
      if (c.timelineEndMs > maxEnd) maxEnd = c.timelineEndMs;
    }
    return maxEnd;
  }

  Future<int?> _probeDurationMs(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }
}
