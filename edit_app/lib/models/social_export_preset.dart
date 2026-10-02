import '../models/project.dart';

/// Preset export social (Fase 3).
enum SocialExportPreset {
  tiktok(
    'TikTok / Reels / Shorts',
    '9:16 · 1080×1920',
    1080,
    1920,
    AspectPreset.vertical916,
  ),
  youtubeHorizontal(
    'YouTube',
    '16:9 · 1920×1080',
    1920,
    1080,
    AspectPreset.horizontal169,
  ),
  square(
    'Feed quadrato',
    '1:1 · 1080×1080',
    1080,
    1080,
    AspectPreset.square11,
  );

  const SocialExportPreset(
    this.label,
    this.detail,
    this.width,
    this.height,
    this.aspect,
  );

  final String label;
  final String detail;
  final int width;
  final int height;
  final AspectPreset aspect;
}
