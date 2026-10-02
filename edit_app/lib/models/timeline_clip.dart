enum TrackKind { video, audio, text }

enum ImageMotion {
  none,
  kenBurnsIn,
  kenBurnsOut,
  panLeft,
  panRight,
}

enum TextMotion {
  none,
  fadeIn,
  slideUp,
  slideDown,
}

/// Clip sulla timeline (path media su disco — niente frame in RAM).
class TimelineClip {
  TimelineClip({
    required this.id,
    required this.mediaId,
    required this.sourceStartMs,
    required this.sourceEndMs,
    required this.timelineStartMs,
    this.trackKind = TrackKind.video,
    this.trackIndex = 0,
    this.volume = 1.0,
    this.text,
    this.imageMotion = ImageMotion.none,
    this.textMotion = TextMotion.none,
    this.backgroundRemoved = false,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
  });

  final String id;
  final String mediaId;
  TrackKind trackKind;
  int trackIndex;
  int sourceStartMs;
  int sourceEndMs;
  int timelineStartMs;
  double volume;
  String? text;
  ImageMotion imageMotion;
  TextMotion textMotion;
  bool backgroundRemoved;

  /// Enhance: brightness −1…1, contrast/saturation tipicamente 0.5…1.5.
  double brightness;
  double contrast;
  double saturation;

  int get durationMs => (sourceEndMs - sourceStartMs).clamp(0, 1 << 30);
  int get timelineEndMs => timelineStartMs + durationMs;
  bool get isCaption => trackKind == TrackKind.text;

  bool get hasEnhance =>
      brightness.abs() > 0.01 ||
      (contrast - 1).abs() > 0.01 ||
      (saturation - 1).abs() > 0.01;

  TimelineClip copy() => TimelineClip(
        id: id,
        mediaId: mediaId,
        sourceStartMs: sourceStartMs,
        sourceEndMs: sourceEndMs,
        timelineStartMs: timelineStartMs,
        trackKind: trackKind,
        trackIndex: trackIndex,
        volume: volume,
        text: text,
        imageMotion: imageMotion,
        textMotion: textMotion,
        backgroundRemoved: backgroundRemoved,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaId': mediaId,
        'sourceStartMs': sourceStartMs,
        'sourceEndMs': sourceEndMs,
        'timelineStartMs': timelineStartMs,
        'trackKind': trackKind.name,
        'trackIndex': trackIndex,
        'volume': volume,
        if (text != null) 'text': text,
        'imageMotion': imageMotion.name,
        'textMotion': textMotion.name,
        'backgroundRemoved': backgroundRemoved,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
      };

  factory TimelineClip.fromJson(Map<String, dynamic> json) {
    return TimelineClip(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String? ?? '',
      sourceStartMs: json['sourceStartMs'] as int,
      sourceEndMs: json['sourceEndMs'] as int,
      timelineStartMs: json['timelineStartMs'] as int? ?? 0,
      trackKind: TrackKind.values.firstWhere(
        (k) => k.name == json['trackKind'],
        orElse: () => TrackKind.video,
      ),
      trackIndex: json['trackIndex'] as int? ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      text: json['text'] as String?,
      imageMotion: ImageMotion.values.firstWhere(
        (e) => e.name == json['imageMotion'],
        orElse: () => ImageMotion.none,
      ),
      textMotion: TextMotion.values.firstWhere(
        (e) => e.name == json['textMotion'],
        orElse: () => TextMotion.none,
      ),
      backgroundRemoved: json['backgroundRemoved'] as bool? ?? false,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1,
    );
  }
}
