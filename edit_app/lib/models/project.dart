import 'timeline_clip.dart';

/// Aspect ratio canvas del progetto.
enum AspectPreset {
  vertical916('9:16', 9 / 16),
  horizontal169('16:9', 16 / 9),
  square11('1:1', 1);

  const AspectPreset(this.label, this.ratio);
  final String label;
  final double ratio;

  static AspectPreset fromName(String name) {
    return AspectPreset.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AspectPreset.vertical916,
    );
  }
}

enum MediaKind { video, image, audio }

/// Documento progetto locale (`project.json`).
class EditProject {
  EditProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.aspect = AspectPreset.vertical916,
    List<MediaRef>? media,
    TimelineData? timeline,
  })  : media = media ?? [],
        timeline = timeline ?? TimelineData();

  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  AspectPreset aspect;
  List<MediaRef> media;
  TimelineData timeline;

  MediaRef? mediaById(String id) {
    for (final m in media) {
      if (m.id == id) return m;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'aspect': aspect.name,
        'media': media.map((m) => m.toJson()).toList(),
        'timeline': timeline.toJson(),
      };

  factory EditProject.fromJson(Map<String, dynamic> json) {
    return EditProject(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      aspect: AspectPreset.fromName(json['aspect'] as String? ?? 'vertical916'),
      media: (json['media'] as List<dynamic>? ?? [])
          .map((e) => MediaRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeline: json['timeline'] != null
          ? TimelineData.fromJson(json['timeline'] as Map<String, dynamic>)
          : TimelineData(),
    );
  }
}

class MediaRef {
  const MediaRef({
    required this.id,
    required this.fileName,
    required this.kind,
    this.durationMs,
    this.displayName,
  });

  final String id;
  final String fileName;
  final MediaKind kind;
  final int? durationMs;
  final String? displayName;

  String get label => displayName ?? fileName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'kind': kind.name,
        if (durationMs != null) 'durationMs': durationMs,
        if (displayName != null) 'displayName': displayName,
      };

  factory MediaRef.fromJson(Map<String, dynamic> json) {
    return MediaRef(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      kind: MediaKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => MediaKind.video,
      ),
      durationMs: json['durationMs'] as int?,
      displayName: json['displayName'] as String?,
    );
  }
}

class TimelineData {
  TimelineData({
    List<TimelineClip>? clips,
    this.videoTrackCount = 2,
    this.audioTrackCount = 2,
    this.textTrackCount = 1,
  }) : clips = clips ?? [];

  /// Tutti i clip (video + audio + testo).
  final List<TimelineClip> clips;

  int videoTrackCount;
  int audioTrackCount;
  int textTrackCount;

  List<TimelineClip> get videoClips => clips
      .where((c) => c.trackKind == TrackKind.video)
      .toList(growable: false);

  List<TimelineClip> get audioClips => clips
      .where((c) => c.trackKind == TrackKind.audio)
      .toList(growable: false);

  List<TimelineClip> get textClips => clips
      .where((c) => c.trackKind == TrackKind.text)
      .toList(growable: false);

  List<TimelineClip> clipsOn(TrackKind kind, int index) => clips
      .where((c) => c.trackKind == kind && c.trackIndex == index)
      .toList(growable: false);

  int get totalDurationMs {
    if (clips.isEmpty) return 0;
    var maxEnd = 0;
    for (final c in clips) {
      if (c.timelineEndMs > maxEnd) maxEnd = c.timelineEndMs;
    }
    return maxEnd;
  }

  void reflowTrack(TrackKind kind, int index) {
    final track = clipsOn(kind, index)
      ..sort((a, b) => a.timelineStartMs.compareTo(b.timelineStartMs));
    var t = 0;
    for (final c in track) {
      c.timelineStartMs = t;
      t += c.durationMs;
    }
  }

  void reflowClipTrack(TimelineClip clip) {
    reflowTrack(clip.trackKind, clip.trackIndex);
  }

  void addAudioTrack() {
    audioTrackCount += 1;
  }

  void addVideoTrack() {
    videoTrackCount += 1;
  }

  Map<String, dynamic> toJson() => {
        'clips': clips.map((c) => c.toJson()).toList(),
        'videoTrackCount': videoTrackCount,
        'audioTrackCount': audioTrackCount,
        'textTrackCount': textTrackCount,
      };

  factory TimelineData.fromJson(Map<String, dynamic> json) {
    if (json['clips'] is List) {
      final raw = json['clips'] as List<dynamic>;
      return TimelineData(
        clips: raw
            .map((e) => TimelineClip.fromJson(e as Map<String, dynamic>))
            .toList(),
        videoTrackCount: json['videoTrackCount'] as int? ?? 2,
        audioTrackCount: json['audioTrackCount'] as int? ?? 2,
        textTrackCount: json['textTrackCount'] as int? ?? 1,
      );
    }
    final raw = json['videoClips'] as List<dynamic>? ?? [];
    return TimelineData(
      clips: raw.map((e) {
        final m = e as Map<String, dynamic>;
        if (!m.containsKey('mediaId')) return null;
        return TimelineClip.fromJson(m);
      }).whereType<TimelineClip>().toList(),
    );
  }
}
