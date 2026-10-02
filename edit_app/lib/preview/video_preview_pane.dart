import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../editor/editor_controller.dart';
import '../models/project.dart';
import '../models/timeline_clip.dart';
import '../theme/tokens.dart';

class VideoPreviewPane extends StatelessWidget {
  const VideoPreviewPane({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final player = controller.player;
        final t = controller.playheadMs;
        final caption = _captionAt(t);
        final imageClip = _imageClipAt(t);

        return ColoredBox(
          color: EditTokens.bg,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.project.aspect.ratio,
                    child: Container(
                      margin: const EdgeInsets.all(EditTokens.spaceMd),
                      decoration: BoxDecoration(
                        color: EditTokens.surfaceHigh,
                        borderRadius:
                            BorderRadius.circular(EditTokens.radiusSm),
                        border: Border.all(color: EditTokens.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (player != null && player.value.isInitialized)
                            ColorFiltered(
                              colorFilter: _enhanceFilter(_videoClipAt(t)),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: player.value.size.width,
                                  height: player.value.size.height,
                                  child: VideoPlayer(player),
                                ),
                              ),
                            )
                          else if (imageClip != null)
                            FutureBuilder<String>(
                              future: _imagePath(imageClip),
                              builder: (context, snap) {
                                if (!snap.hasData) {
                                  return const SizedBox.shrink();
                                }
                                final prog = _progress(imageClip, t);
                                return ColorFiltered(
                                  colorFilter: _enhanceFilter(imageClip),
                                  child: Transform.scale(
                                    scale: _imageScale(imageClip, prog),
                                    alignment: _imageAlign(imageClip, prog),
                                    child: Image.file(
                                      File(snap.data!),
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            Center(
                              child: Text(
                                controller.project.timeline.videoClips.isEmpty
                                    ? 'Importa un video per iniziare'
                                    : 'Caricamento…',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (caption != null)
                            _CaptionOverlay(clip: caption, playheadMs: t),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _TransportBar(controller: controller),
            ],
          ),
        );
      },
    );
  }

  TimelineClip? _videoClipAt(int ms) {
    for (final c in controller.project.timeline.videoClips) {
      if (ms >= c.timelineStartMs && ms < c.timelineEndMs) {
        final m = controller.project.mediaById(c.mediaId);
        if (m?.kind == MediaKind.video) return c;
      }
    }
    return controller.selectedClip?.trackKind == TrackKind.video
        ? controller.selectedClip
        : null;
  }

  ColorFilter _enhanceFilter(TimelineClip? clip) {
    if (clip == null || !clip.hasEnhance) {
      return const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    // Approssimazione preview: matrix luminosità/contrasto/saturazione.
    final b = clip.brightness;
    final c = clip.contrast;
    final s = clip.saturation;
    final invSat = 1 - s;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final r = invSat * lr;
    final g = invSat * lg;
    final bl = invSat * lb;
    return ColorFilter.matrix(<double>[
      c * (r + s), c * g, c * bl, 0, b * 255,
      c * r, c * (g + s), c * bl, 0, b * 255,
      c * r, c * g, c * (bl + s), 0, b * 255,
      0, 0, 0, 1, 0,
    ]);
  }

  TimelineClip? _captionAt(int ms) {
    for (final c in controller.project.timeline.textClips) {
      if (ms >= c.timelineStartMs && ms < c.timelineEndMs) return c;
    }
    return null;
  }

  TimelineClip? _imageClipAt(int ms) {
    for (final c in controller.project.timeline.videoClips) {
      if (ms < c.timelineStartMs || ms >= c.timelineEndMs) continue;
      final m = controller.project.mediaById(c.mediaId);
      if (m?.kind == MediaKind.image) return c;
    }
    return null;
  }

  Future<String> _imagePath(TimelineClip clip) async {
    final m = controller.project.mediaById(clip.mediaId)!;
    return controller.mediaPath(m);
  }

  double _progress(TimelineClip clip, int ms) {
    final d = clip.durationMs;
    if (d <= 0) return 0;
    return ((ms - clip.timelineStartMs) / d).clamp(0.0, 1.0);
  }

  double _imageScale(TimelineClip clip, double p) {
    switch (clip.imageMotion) {
      case ImageMotion.kenBurnsIn:
        return 1.0 + 0.12 * p;
      case ImageMotion.kenBurnsOut:
        return 1.12 - 0.12 * p;
      default:
        return 1.0;
    }
  }

  Alignment _imageAlign(TimelineClip clip, double p) {
    switch (clip.imageMotion) {
      case ImageMotion.panLeft:
        return Alignment(-0.3 + 0.6 * p, 0);
      case ImageMotion.panRight:
        return Alignment(0.3 - 0.6 * p, 0);
      default:
        return Alignment.center;
    }
  }
}

class _CaptionOverlay extends StatelessWidget {
  const _CaptionOverlay({required this.clip, required this.playheadMs});

  final TimelineClip clip;
  final int playheadMs;

  @override
  Widget build(BuildContext context) {
    final p = ((playheadMs - clip.timelineStartMs) / clip.durationMs)
        .clamp(0.0, 1.0);
    double opacity = 1;
    Offset offset = Offset.zero;
    switch (clip.textMotion) {
      case TextMotion.fadeIn:
        opacity = (p / 0.25).clamp(0.0, 1.0);
      case TextMotion.slideUp:
        opacity = (p / 0.2).clamp(0.0, 1.0);
        offset = Offset(0, 24 * (1 - opacity));
      case TextMotion.slideDown:
        opacity = (p / 0.2).clamp(0.0, 1.0);
        offset = Offset(0, -24 * (1 - opacity));
      case TextMotion.none:
        break;
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: offset,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              clip.text ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportBar extends StatelessWidget {
  const _TransportBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final total = controller.project.timeline.totalDurationMs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: controller.isPlaying ? 'Pausa' : 'Play',
            onPressed: controller.project.timeline.clips.isEmpty
                ? null
                : controller.togglePlay,
            icon: Icon(
              controller.isPlaying ? Icons.pause : Icons.play_arrow,
              color: EditTokens.text,
            ),
          ),
          Text(
            '${_fmt(controller.playheadMs)} / ${_fmt(total)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            controller.project.aspect.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _fmt(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}
