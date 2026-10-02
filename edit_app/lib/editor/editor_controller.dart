import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../models/project.dart';
import '../models/social_export_preset.dart';
import '../models/timeline_clip.dart';
import '../services/audio_denoise_service.dart';
import '../services/background_remove_service.dart';
import '../services/caption_service.dart';
import '../services/export_service.dart';
import '../services/media_import_service.dart';
import '../services/project_store.dart';
import '../services/undo_history.dart';

/// Sezione attiva del pannello destro (dinamico).
enum InspectorSection {
  media,
  audio,
  text,
  removeBg,
  enhance,
  cleanAudio,
}

/// Stato editor: un solo VideoPlayerController attivo (risparmio RAM).
class EditorController extends ChangeNotifier {
  EditorController({
    required this.store,
    required this.project,
    MediaImportService? importService,
    ExportService? exportService,
    CaptionService? captionService,
    BackgroundRemoveService? bgService,
    AudioDenoiseService? denoiseService,
    Uuid? uuid,
  })  : _import = importService ?? MediaImportService(store),
        _export = exportService ?? ExportService(store),
        _captions = captionService ?? CaptionService(store),
        _bg = bgService ?? BackgroundRemoveService(store),
        _denoise = denoiseService ?? AudioDenoiseService(store),
        _uuid = uuid ?? const Uuid();

  final ProjectStore store;
  final MediaImportService _import;
  final ExportService _export;
  final CaptionService _captions;
  final BackgroundRemoveService _bg;
  final AudioDenoiseService _denoise;
  final Uuid _uuid;
  EditProject project;

  final UndoHistory _history = UndoHistory();

  VideoPlayerController? _player;
  String? _loadedMediaId;
  String? _selectedClipId;
  int playheadMs = 0;
  bool isPlaying = false;
  bool isBusy = false;
  String? statusMessage;
  InspectorSection inspectorSection = InspectorSection.media;
  int targetVideoTrack = 0;
  int targetAudioTrack = 0;
  /// Se true, l’inspector destro è visibile.
  bool inspectorOpen = true;

  void setTargetVideoTrack(int index) {
    targetVideoTrack =
        index.clamp(0, project.timeline.videoTrackCount - 1);
    notifyListeners();
  }

  void setTargetAudioTrack(int index) {
    targetAudioTrack =
        index.clamp(0, project.timeline.audioTrackCount - 1);
    notifyListeners();
  }

  VideoPlayerController? get player => _player;
  String? get selectedClipId => _selectedClipId;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  List<TimelineClip> get allClips => project.timeline.clips;

  TimelineClip? get selectedClip {
    final id = _selectedClipId;
    if (id == null) return null;
    for (final c in allClips) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> init() async {
    final videos = project.timeline.videoClips;
    if (videos.isNotEmpty) {
      _selectedClipId = videos.first.id;
      await _ensurePlayerForClip(videos.first);
      await seekPlayhead(0);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  void setInspectorSection(InspectorSection section) {
    inspectorSection = section;
    inspectorOpen = true;
    notifyListeners();
  }

  void toggleInspector() {
    inspectorOpen = !inspectorOpen;
    notifyListeners();
  }

  Future<String> mediaPath(MediaRef media) async {
    final dir = await store.projectDir(project.id);
    return p.join(dir.path, 'media', media.fileName);
  }

  void _pushHistory() {
    _history.push(jsonEncode(project.timeline.toJson()));
  }

  void _restoreTimeline(String snapshot) {
    final map = jsonDecode(snapshot) as Map<String, dynamic>;
    project.timeline = TimelineData.fromJson(map);
    if (allClips.isEmpty) {
      _selectedClipId = null;
    } else if (_selectedClipId == null ||
        allClips.every((c) => c.id != _selectedClipId)) {
      _selectedClipId = allClips.first.id;
    }
  }

  Future<void> undo() async {
    final snap = _history.undo(jsonEncode(project.timeline.toJson()));
    if (snap == null) return;
    _restoreTimeline(snap);
    await store.saveProject(project);
    await _syncPlayerToPlayhead();
    notifyListeners();
  }

  Future<void> redo() async {
    final snap = _history.redo(jsonEncode(project.timeline.toJson()));
    if (snap == null) return;
    _restoreTimeline(snap);
    await store.saveProject(project);
    await _syncPlayerToPlayhead();
    notifyListeners();
  }

  Future<void> setAspect(AspectPreset aspect) async {
    project.aspect = aspect;
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> rename(String name) async {
    await store.renameProject(project, name);
    notifyListeners();
  }

  Future<void> importVideo(String path, {int? trackIndex}) async {
    isBusy = true;
    statusMessage = 'Import…';
    notifyListeners();
    try {
      _pushHistory();
      await _import.importVideoFile(
        project: project,
        sourcePath: path,
        trackIndex: trackIndex ?? targetVideoTrack,
      );
      final last = project.timeline.videoClips.last;
      _selectedClipId = last.id;
      await _ensurePlayerForClip(last);
      await seekPlayhead(last.timelineStartMs);
      statusMessage = null;
    } catch (e) {
      statusMessage = 'Import fallito';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> importAny(String path) async {
    isBusy = true;
    statusMessage = 'Import…';
    notifyListeners();
    try {
      _pushHistory();
      await _import.importFile(
        project: project,
        sourcePath: path,
        trackKind: TrackKind.video,
        trackIndex: targetVideoTrack,
      );
      final last = allClips.last;
      _selectedClipId = last.id;
      if (last.trackKind == TrackKind.video) {
        final media = project.mediaById(last.mediaId);
        if (media?.kind == MediaKind.video) {
          await _ensurePlayerForClip(last);
        }
      }
      await seekPlayhead(last.timelineStartMs);
      inspectorSection = InspectorSection.media;
      statusMessage = null;
    } catch (e) {
      statusMessage = 'Import fallito';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> importAudio(String path, {int? trackIndex}) async {
    isBusy = true;
    statusMessage = 'Import audio…';
    notifyListeners();
    try {
      _pushHistory();
      await _import.importFile(
        project: project,
        sourcePath: path,
        trackKind: TrackKind.audio,
        trackIndex: trackIndex ?? targetAudioTrack,
      );
      _selectedClipId = project.timeline.audioClips.last.id;
      inspectorSection = InspectorSection.audio;
      statusMessage = null;
    } catch (e) {
      statusMessage = 'Import audio fallito';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> addAudioTrack() async {
    _pushHistory();
    project.timeline.addAudioTrack();
    targetAudioTrack = project.timeline.audioTrackCount - 1;
    inspectorSection = InspectorSection.audio;
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> addVideoTrack() async {
    _pushHistory();
    project.timeline.addVideoTrack();
    targetVideoTrack = project.timeline.videoTrackCount - 1;
    inspectorSection = InspectorSection.media;
    await store.saveProject(project);
    notifyListeners();
  }

  /// Durata clip (immagini/caption libere; video = trim fine entro il media).
  Future<void> setClipDurationMs(int durationMs, {bool recordHistory = true}) async {
    final clip = selectedClip;
    if (clip == null) return;
    final media = project.mediaById(clip.mediaId);
    final minD = 200;
    final next = durationMs.clamp(minD, 1 << 30);
    if (recordHistory) _pushHistory();
    if (media?.kind == MediaKind.image || clip.isCaption || media == null) {
      clip.sourceStartMs = 0;
      clip.sourceEndMs = next.clamp(minD, 30 * 60 * 1000);
    } else {
      final maxEnd = media.durationMs ?? clip.sourceEndMs;
      clip.sourceEndMs =
          (clip.sourceStartMs + next).clamp(clip.sourceStartMs + minD, maxEnd);
    }
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> setClipVolumeById(
    String clipId,
    double volume, {
    bool recordHistory = true,
    bool persist = true,
  }) async {
    TimelineClip? clip;
    for (final c in project.timeline.clips) {
      if (c.id == clipId) {
        clip = c;
        break;
      }
    }
    if (clip == null) return;
    if (recordHistory) _pushHistory();
    clip.volume = volume.clamp(0.0, 1.0);
    _selectedClipId = clipId;
    if (persist) await store.saveProject(project);
    notifyListeners();
  }

  Future<void> setClipDurationById(
    String clipId,
    int durationMs, {
    bool recordHistory = true,
    bool persist = true,
  }) async {
    TimelineClip? clip;
    for (final c in project.timeline.clips) {
      if (c.id == clipId) {
        clip = c;
        break;
      }
    }
    if (clip == null) return;
    final media = project.mediaById(clip.mediaId);
    final minD = 200;
    final next = durationMs.clamp(minD, 1 << 30);
    if (recordHistory) _pushHistory();
    if (media?.kind == MediaKind.image || clip.isCaption || media == null) {
      clip.sourceStartMs = 0;
      clip.sourceEndMs = next.clamp(minD, 30 * 60 * 1000);
    } else {
      final maxEnd = media.durationMs ?? clip.sourceEndMs;
      clip.sourceEndMs =
          (clip.sourceStartMs + next).clamp(clip.sourceStartMs + minD, maxEnd);
    }
    _selectedClipId = clipId;
    if (persist) await store.saveProject(project);
    notifyListeners();
  }

  /// Copia take VO dal temp nella sandbox e lo mette su traccia audio.
  Future<void> attachVoiceRecording({
    required String tempPath,
    required int durationMs,
  }) async {
    isBusy = true;
    statusMessage = 'Salvo VO…';
    notifyListeners();
    try {
      _pushHistory();
      await _import.importVoiceFile(
        project: project,
        sourcePath: tempPath,
        durationMs: durationMs,
        trackIndex: targetAudioTrack,
        timelineStartMs: playheadMs,
      );
      _selectedClipId = project.timeline.audioClips.last.id;
      inspectorSection = InspectorSection.audio;
      statusMessage = null;
      try {
        await File(tempPath).delete();
      } catch (_) {}
    } catch (e) {
      statusMessage = 'VO fallita';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> addCaption({String text = 'Testo', int durationMs = 3000}) async {
    _pushHistory();
    final start = playheadMs;
    final clip = TimelineClip(
      id: _uuid.v4(),
      mediaId: '',
      sourceStartMs: 0,
      sourceEndMs: durationMs,
      timelineStartMs: start,
      trackKind: TrackKind.text,
      trackIndex: 0,
      text: text,
    );
    project.timeline.clips.add(clip);
    _selectedClipId = clip.id;
    inspectorSection = InspectorSection.text;
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> updateCaptionText(String text) async {
    final clip = selectedClip;
    if (clip == null || !clip.isCaption) return;
    clip.text = text;
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> setClipVolume(double volume, {bool recordHistory = true}) async {
    final clip = selectedClip;
    if (clip == null) return;
    if (recordHistory) _pushHistory();
    clip.volume = volume.clamp(0.0, 1.0);
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> setImageMotion(ImageMotion motion) async {
    final clip = selectedClip;
    if (clip == null) return;
    _pushHistory();
    clip.imageMotion = motion;
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> setTextMotion(TextMotion motion) async {
    final clip = selectedClip;
    if (clip == null || !clip.isCaption) return;
    _pushHistory();
    clip.textMotion = motion;
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> generateAutoCaptions() async {
    MediaRef? source;
    final sel = selectedClip;
    if (sel != null && sel.mediaId.isNotEmpty) {
      source = project.mediaById(sel.mediaId);
    }
    source ??= () {
      for (final m in project.media) {
        if (m.kind == MediaKind.audio || m.kind == MediaKind.video) return m;
      }
      return null;
    }();
    if (source == null) {
      throw StateError('Importa prima un audio o un video');
    }

    isBusy = true;
    statusMessage = 'Sottotitoli…';
    notifyListeners();
    try {
      _pushHistory();
      final cues = await _captions.transcribeMediaFile(
        projectId: project.id,
        mediaFileName: source.fileName,
      );
      final clips = _captions.cuesToClips(cues);
      project.timeline.clips.removeWhere((c) => c.trackKind == TrackKind.text);
      project.timeline.clips.addAll(clips);
      if (clips.isNotEmpty) _selectedClipId = clips.first.id;
      inspectorSection = InspectorSection.text;
      await store.saveProject(project);
      statusMessage = '${clips.length} caption';
    } catch (e) {
      statusMessage = 'STT fallita';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> removeBackgroundOnSelected() async {
    final clip = selectedClip;
    if (clip == null || clip.mediaId.isEmpty) {
      throw StateError('Seleziona un clip immagine o video');
    }
    final media = project.mediaById(clip.mediaId);
    if (media == null ||
        (media.kind != MediaKind.image && media.kind != MediaKind.video)) {
      throw StateError('Solo immagini o video');
    }

    isBusy = true;
    statusMessage = 'Rimuovo sfondo…';
    notifyListeners();
    try {
      _pushHistory();
      final out = await _bg.removeBackground(project: project, source: media);
      project.media = [...project.media, out];
      // mediaId is final on TimelineClip - need to replace clip
      final idx = project.timeline.clips.indexOf(clip);
      if (idx >= 0) {
        final next = TimelineClip(
          id: clip.id,
          mediaId: out.id,
          sourceStartMs: clip.sourceStartMs,
          sourceEndMs: clip.sourceEndMs,
          timelineStartMs: clip.timelineStartMs,
          trackKind: clip.trackKind,
          trackIndex: clip.trackIndex,
          volume: clip.volume,
          text: clip.text,
          imageMotion: clip.imageMotion,
          textMotion: clip.textMotion,
          backgroundRemoved: true,
          brightness: clip.brightness,
          contrast: clip.contrast,
          saturation: clip.saturation,
        );
        project.timeline.clips[idx] = next;
        _selectedClipId = next.id;
      }
      _loadedMediaId = null;
      await store.saveProject(project);
      statusMessage = 'Sfondo rimosso';
    } catch (e) {
      statusMessage = 'Rembg fallita';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> denoiseSelected() async {
    final clip = selectedClip;
    if (clip == null || clip.mediaId.isEmpty) {
      throw StateError('Seleziona un clip audio o video');
    }
    final media = project.mediaById(clip.mediaId);
    if (media == null) throw StateError('Media mancante');

    isBusy = true;
    statusMessage = 'Pulisco audio…';
    notifyListeners();
    try {
      _pushHistory();
      final out = await _denoise.denoise(project: project, source: media);
      project.media = [...project.media, out];
      final idx = project.timeline.clips.indexOf(clip);
      if (idx >= 0) {
        project.timeline.clips[idx] = TimelineClip(
          id: clip.id,
          mediaId: out.id,
          sourceStartMs: clip.sourceStartMs,
          sourceEndMs: clip.sourceEndMs,
          timelineStartMs: clip.timelineStartMs,
          trackKind: clip.trackKind,
          trackIndex: clip.trackIndex,
          volume: clip.volume,
          text: clip.text,
          imageMotion: clip.imageMotion,
          textMotion: clip.textMotion,
          backgroundRemoved: clip.backgroundRemoved,
          brightness: clip.brightness,
          contrast: clip.contrast,
          saturation: clip.saturation,
        );
        _selectedClipId = project.timeline.clips[idx].id;
      }
      _loadedMediaId = null;
      await store.saveProject(project);
      statusMessage = 'Audio pulito';
    } catch (e) {
      statusMessage = 'Denoise fallita';
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> setEnhance({
    double? brightness,
    double? contrast,
    double? saturation,
    bool recordHistory = true,
  }) async {
    final clip = selectedClip;
    if (clip == null) return;
    if (recordHistory) _pushHistory();
    if (brightness != null) clip.brightness = brightness.clamp(-1.0, 1.0);
    if (contrast != null) clip.contrast = contrast.clamp(0.5, 2.0);
    if (saturation != null) clip.saturation = saturation.clamp(0.0, 2.0);
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> resetEnhance() async {
    await setEnhance(brightness: 0, contrast: 1, saturation: 1);
  }

  Future<void> placeMediaOnTimeline(MediaRef media, {TrackKind? kind, int? trackIndex}) async {
    _pushHistory();
    final resolvedKind = kind ??
        (media.kind == MediaKind.audio ? TrackKind.audio : TrackKind.video);
    final idx = trackIndex ??
        (resolvedKind == TrackKind.audio ? targetAudioTrack : targetVideoTrack);
    final dur = media.durationMs ?? 3000;
    final start = _endOfTrack(resolvedKind, idx);
    final clip = TimelineClip(
      id: _uuid.v4(),
      mediaId: media.id,
      sourceStartMs: 0,
      sourceEndMs: dur,
      timelineStartMs: start,
      trackKind: resolvedKind,
      trackIndex: idx,
    );
    project.timeline.clips.add(clip);
    _selectedClipId = clip.id;
    await store.saveProject(project);
    notifyListeners();
  }

  int _endOfTrack(TrackKind kind, int index) {
    final track = project.timeline.clipsOn(kind, index);
    if (track.isEmpty) return 0;
    var maxEnd = 0;
    for (final c in track) {
      if (c.timelineEndMs > maxEnd) maxEnd = c.timelineEndMs;
    }
    return maxEnd;
  }

  void selectClip(String? id) {
    _selectedClipId = id;
    notifyListeners();
  }

  /// Aggiorna subito il playhead (scrubbing fluido). Sync player in differita.
  void scrubPlayhead(int ms, {int? maxMs}) {
    final total = project.timeline.totalDurationMs;
    final hi = maxMs ??
        (total > 60 * 60 * 1000 ? total + 10 * 60 * 1000 : 60 * 60 * 1000);
    final next = ms.clamp(0, hi);
    if (playheadMs == next) return;
    playheadMs = next;
    notifyListeners();
    _schedulePlayerSync();
  }

  Future<void>? _playerSyncFuture;

  void _schedulePlayerSync() {
    if (_playerSyncFuture != null) return;
    _playerSyncFuture = Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      _playerSyncFuture = null;
      await _syncPlayerToPlayhead();
    });
  }

  Future<void> seekPlayhead(int ms, {int? maxMs}) async {
    final total = project.timeline.totalDurationMs;
    final hi = maxMs ??
        (total > 60 * 60 * 1000 ? total + 10 * 60 * 1000 : 60 * 60 * 1000);
    playheadMs = ms.clamp(0, hi);
    notifyListeners();
    await _syncPlayerToPlayhead();
  }

  Future<void> _syncPlayerToPlayhead() async {
    final clip = _videoClipAt(playheadMs);
    if (clip == null) {
      // Fuori da clip video: non forzare l’ultimo clip (asta libera).
      await _player?.pause();
      isPlaying = false;
      return;
    }
    await _ensurePlayerForClip(clip);
    final local = playheadMs - clip.timelineStartMs + clip.sourceStartMs;
    await _player?.seekTo(Duration(milliseconds: local));
  }

  /// Playback: preferisce V1, poi V2. Solo se il playhead è DENTRO un clip.
  TimelineClip? _videoClipAt(int ms) {
    for (var t = 0; t < project.timeline.videoTrackCount; t++) {
      for (final c in project.timeline.clipsOn(TrackKind.video, t)) {
        if (ms >= c.timelineStartMs && ms < c.timelineEndMs) return c;
      }
    }
    return null;
  }

  TimelineClip? _clipAtPlayheadAny() {
    for (final c in allClips) {
      if (playheadMs >= c.timelineStartMs && playheadMs < c.timelineEndMs) {
        return c;
      }
    }
    return selectedClip ?? (allClips.isEmpty ? null : allClips.first);
  }

  Future<void> _ensurePlayerForClip(TimelineClip clip) async {
    final media = project.mediaById(clip.mediaId);
    if (media == null || media.kind != MediaKind.video) return;
    if (_loadedMediaId == clip.mediaId && _player != null) return;
    final path = await mediaPath(media);
    final next = VideoPlayerController.file(File(path));
    await next.initialize();
    await _player?.dispose();
    _player = next;
    _loadedMediaId = clip.mediaId;
    _player!.addListener(_onPlayerTick);
  }

  void _onPlayerTick() {
    final player = _player;
    final clip = _videoClipAt(playheadMs);
    if (player == null || clip == null || !isPlaying) return;
    if (_selectedClipId != clip.id) {
      // playhead su altro clip: gestito sotto
    }
    final srcMs = player.value.position.inMilliseconds;
    final active = selectedClip?.trackKind == TrackKind.video
        ? selectedClip
        : clip;
    if (active == null) return;
    if (srcMs >= active.sourceEndMs) {
      final next = _nextVideoClip(active);
      if (next != null) {
        seekPlayhead(next.timelineStartMs).then((_) => play());
      } else {
        pause();
        seekPlayhead(active.timelineEndMs);
      }
      return;
    }
    playheadMs = active.timelineStartMs + (srcMs - active.sourceStartMs);
    notifyListeners();
  }

  TimelineClip? _nextVideoClip(TimelineClip current) {
    final videos = [...project.timeline.videoClips]
      ..sort((a, b) => a.timelineStartMs.compareTo(b.timelineStartMs));
    final idx = videos.indexWhere((c) => c.id == current.id);
    if (idx < 0 || idx + 1 >= videos.length) return null;
    return videos[idx + 1];
  }

  Future<void> play() async {
    if (project.timeline.videoClips.isEmpty) return;
    final clip = _videoClipAt(playheadMs) ?? project.timeline.videoClips.first;
    await _ensurePlayerForClip(clip);
    _selectedClipId = clip.id;
    final local = playheadMs - clip.timelineStartMs + clip.sourceStartMs;
    if (local < clip.sourceStartMs || local >= clip.sourceEndMs) {
      await _player?.seekTo(Duration(milliseconds: clip.sourceStartMs));
      playheadMs = clip.timelineStartMs;
    }
    await _player?.play();
    isPlaying = true;
    notifyListeners();
  }

  Future<void> pause() async {
    await _player?.pause();
    isPlaying = false;
    notifyListeners();
  }

  Future<void> togglePlay() => isPlaying ? pause() : play();

  Future<void> splitAtPlayhead() async {
    final clip = selectedClip ?? _clipAtPlayheadAny();
    if (clip == null) return;
    if (playheadMs <= clip.timelineStartMs + 120 ||
        playheadMs >= clip.timelineEndMs - 120) {
      return;
    }
    final offset = playheadMs - clip.timelineStartMs;
    _pushHistory();
    final cutSource = clip.sourceStartMs + offset;
    final right = TimelineClip(
      id: _uuid.v4(),
      mediaId: clip.mediaId,
      sourceStartMs: cutSource,
      sourceEndMs: clip.sourceEndMs,
      timelineStartMs: playheadMs,
      trackKind: clip.trackKind,
      trackIndex: clip.trackIndex,
    );
    clip.sourceEndMs = cutSource;
    final idx = project.timeline.clips.indexOf(clip);
    project.timeline.clips.insert(idx + 1, right);
    project.timeline.reflowClipTrack(clip);
    _selectedClipId = right.id;
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    final clip = selectedClip;
    if (clip == null) return;
    _pushHistory();
    final kind = clip.trackKind;
    final tIdx = clip.trackIndex;
    project.timeline.clips.removeWhere((c) => c.id == clip.id);
    project.timeline.reflowTrack(kind, tIdx);
    _selectedClipId = allClips.isEmpty ? null : allClips.first.id;
    if (_selectedClipId == null) {
      await _player?.dispose();
      _player = null;
      _loadedMediaId = null;
      playheadMs = 0;
    } else {
      await seekPlayhead(playheadMs.clamp(0, project.timeline.totalDurationMs));
    }
    await store.saveProject(project);
    notifyListeners();
  }

  Future<void> trimSelected({int? newSourceStart, int? newSourceEnd}) async {
    final clip = selectedClip;
    if (clip == null) return;
    _pushHistory();
    if (newSourceStart != null) {
      clip.sourceStartMs = newSourceStart.clamp(0, clip.sourceEndMs - 200);
    }
    if (newSourceEnd != null) {
      final media = project.mediaById(clip.mediaId);
      final maxEnd = media?.durationMs ?? clip.sourceEndMs;
      clip.sourceEndMs =
          newSourceEnd.clamp(clip.sourceStartMs + 200, maxEnd);
    }
    project.timeline.reflowClipTrack(clip);
    await store.saveProject(project);
    await seekPlayhead(clip.timelineStartMs);
    notifyListeners();
  }

  /// Sposta un clip nel tempo (senza reflow: permette allineamenti tra tracce).
  void moveClipStart(String clipId, int newStartMs) {
    for (final c in project.timeline.clips) {
      if (c.id != clipId) continue;
      final start = newStartMs.clamp(0, 1 << 30);
      if (c.timelineStartMs == start) return;
      c.timelineStartMs = start;
      notifyListeners();
      return;
    }
  }

  Future<void> finishClipMove() async {
    await store.saveProject(project);
    notifyListeners();
  }

  void beginClipMoveHistory() => _pushHistory();

  Future<ExportResult> export({SocialExportPreset? social}) async {
    isBusy = true;
    statusMessage = 'Export…';
    notifyListeners();
    try {
      if (social != null && project.aspect != social.aspect) {
        project.aspect = social.aspect;
        await store.saveProject(project);
      }
      final result = await _export.exportProject(project, social: social);
      statusMessage = 'Salvato';
      return result;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
