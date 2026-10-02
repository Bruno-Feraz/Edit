import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../editor/editor_controller.dart';
import '../models/project.dart';
import '../models/timeline_clip.dart';
import '../theme/tokens.dart';
import 'timeline_snap.dart';

/// Scroll timeline con trackpad/rotella; il drag del mouse resta a playhead/clip.
class _TimelineScrollBehavior extends MaterialScrollBehavior {
  const _TimelineScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Timeline continua multi-traccia con ruler, tacche e snap magnetico.
class TimelinePanel extends StatelessWidget {
  const TimelinePanel({super.key, required this.controller});

  final EditorController controller;

  static const double pxPerMs = 0.08;
  static const double trackH = 36;
  static const double labelW = 36;
  static const double rulerH = 28;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tl = controller.project.timeline;
        final total = tl.totalDurationMs;
        // Canvas lungo di default; si estende oltre l’ultimo clip.
        const minContentMs = 60 * 60 * 1000; // 60 minuti
        const tailPadMs = 10 * 60 * 1000; // +10 min dopo l’ultimo media
        final contentMs =
            (total + tailPadMs) < minContentMs ? minContentMs : total + tailPadMs;
        final width = contentMs * pxPerMs;
        final videoN = tl.videoTrackCount;
        final audioN = tl.audioTrackCount;
        final textN = tl.textTrackCount;
        final rowCount = videoN + audioN + textN;
        final addRowH = 28.0;
        final tracksH = rulerH + rowCount * (trackH + 1) + addRowH + 8;

        int rowOf(TimelineClip c) {
          switch (c.trackKind) {
            case TrackKind.video:
              return c.trackIndex;
            case TrackKind.audio:
              return videoN + c.trackIndex;
            case TrackKind.text:
              return videoN + audioN + c.trackIndex;
          }
        }

        return Container(
          color: EditTokens.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    Text('Timeline',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${tl.clips.length} clip · ${_fmt(total)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: tracksH.clamp(160.0, 720.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: labelW + 28,
                          child: Column(
                            children: [
                              SizedBox(height: rulerH),
                              ...List.generate(
                                videoN,
                                (i) => _TrackLabel(
                                  text: 'V${i + 1}',
                                  height: trackH + 1,
                                  color: EditTokens.accent,
                                ),
                              ),
                              ...List.generate(
                                audioN,
                                (i) => _TrackLabel(
                                  text: 'A${i + 1}',
                                  height: trackH + 1,
                                  color: const Color(0xFF7EB6FF),
                                ),
                              ),
                              ...List.generate(
                                textN,
                                (i) => _TrackLabel(
                                  text: 'T${i + 1}',
                                  height: trackH + 1,
                                  color: const Color(0xFFE8C47C),
                                ),
                              ),
                              SizedBox(
                                height: addRowH,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: 'Nuova traccia video',
                                      iconSize: 16,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: controller.addVideoTrack,
                                      icon: const Icon(Icons.videocam_outlined,
                                          color: EditTokens.accent),
                                    ),
                                    IconButton(
                                      tooltip: 'Nuova traccia audio',
                                      iconSize: 16,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: controller.addAudioTrack,
                                      icon: const Icon(Icons.graphic_eq,
                                          color: Color(0xFF7EB6FF)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ScrollConfiguration(
                            behavior: const _TimelineScrollBehavior(),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(right: 16),
                              child: _TimelineCanvas(
                                controller: controller,
                                width: width,
                                height: tracksH,
                                contentMs: contentMs,
                                rowCount: rowCount,
                                rowOf: rowOf,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

class _TimelineCanvas extends StatefulWidget {
  const _TimelineCanvas({
    required this.controller,
    required this.width,
    required this.height,
    required this.contentMs,
    required this.rowCount,
    required this.rowOf,
  });

  final EditorController controller;
  final double width;
  final double height;
  final int contentMs;
  final int rowCount;
  final int Function(TimelineClip) rowOf;

  @override
  State<_TimelineCanvas> createState() => _TimelineCanvasState();
}

class _TimelineCanvasState extends State<_TimelineCanvas> {
  int? _snapGuideMs;
  int? _dragOriginStart;

  double get _ppm => TimelinePanel.pxPerMs;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final tl = c.project.timeline;
    final major = TimelineSnap.majorTickMs(_ppm);
    final minor = TimelineSnap.minorTickMs(major);

    return SizedBox(
      width: widget.width + 24,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _TimelineGridPainter(
                width: widget.width,
                height: widget.height,
                rulerH: TimelinePanel.rulerH,
                trackH: TimelinePanel.trackH,
                rowCount: widget.rowCount,
                contentMs: widget.contentMs,
                pxPerMs: _ppm,
                majorMs: major,
                minorMs: minor,
              ),
            ),
          ),
          // Trasporto / seek sul ruler e sulle lane (sotto i clip).
          Positioned(
            left: 0,
            top: 0,
            width: widget.width,
            height: TimelinePanel.rulerH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _seekAt(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => _seekAt(d.localPosition.dx),
            ),
          ),
          ...List.generate(widget.rowCount, (i) {
            final top =
                TimelinePanel.rulerH + i * (TimelinePanel.trackH + 1);
            return Positioned(
              left: 0,
              top: top,
              width: widget.width,
              height: TimelinePanel.trackH,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => _seekAt(d.localPosition.dx),
              ),
            );
          }),
          ...tl.clips.map((clip) {
            final top = TimelinePanel.rulerH +
                widget.rowOf(clip) * (TimelinePanel.trackH + 1);
            final media = c.project.mediaById(clip.mediaId);
            final isImage = media?.kind == MediaKind.image;
            final hasVolume = clip.trackKind == TrackKind.audio ||
                media?.kind == MediaKind.video;
            return _ClipBlock(
              key: ValueKey(clip.id),
              clip: clip,
              pxPerMs: _ppm,
              top: top + 3,
              height: TimelinePanel.trackH - 6,
              selected: clip.id == c.selectedClipId,
              isImage: isImage,
              hasVolume: hasVolume,
              onTap: () async {
                c.selectClip(clip.id);
                await c.seekPlayhead(
                  clip.timelineStartMs,
                  maxMs: widget.contentMs,
                );
              },
              onDragStart: () {
                _dragOriginStart = clip.timelineStartMs;
                c.beginClipMoveHistory();
                c.selectClip(clip.id);
              },
              onDragDelta: (totalDx) {
                final origin = _dragOriginStart ?? clip.timelineStartMs;
                final raw =
                    (origin + totalDx / _ppm).round().clamp(0, widget.contentMs);
                final snapped = TimelineSnap.snapClipStart(
                  proposedStart: raw,
                  durationMs: clip.durationMs,
                  clipId: clip.id,
                  clips: tl.clips,
                  playheadMs: c.playheadMs,
                  pxPerMs: _ppm,
                );
                setState(() => _snapGuideMs = snapped.guideMs);
                c.moveClipStart(clip.id, snapped.ms);
              },
              onDragEnd: () async {
                setState(() {
                  _snapGuideMs = null;
                  _dragOriginStart = null;
                });
                await c.finishClipMove();
              },
              onResizeDuration: (dur) {
                c.setClipDurationById(clip.id, dur, recordHistory: false);
              },
              onResizeEnd: () async {
                await c.finishClipMove();
              },
              onVolume: (v, {required bool end}) {
                c.setClipVolumeById(clip.id, v, recordHistory: end);
              },
            );
          }),
          if (_snapGuideMs != null)
            Positioned(
              left: _snapGuideMs! * _ppm - 0.5,
              top: 0,
              width: 1,
              height: widget.height,
              child: IgnorePointer(
                child: Container(color: EditTokens.accent.withValues(alpha: 0.85)),
              ),
            ),
          _Playhead(
            ms: c.playheadMs,
            pxPerMs: _ppm,
            height: widget.height,
            maxMs: widget.contentMs,
            onDrag: (ms) {
              c.scrubPlayhead(ms, maxMs: widget.contentMs);
            },
            onDragEnd: () {
              c.seekPlayhead(c.playheadMs, maxMs: widget.contentMs);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _seekAt(double dx) async {
    final raw = (dx / _ppm).round().clamp(0, widget.contentMs);
    widget.controller.scrubPlayhead(raw, maxMs: widget.contentMs);
  }
}

class _TimelineGridPainter extends CustomPainter {
  _TimelineGridPainter({
    required this.width,
    required this.height,
    required this.rulerH,
    required this.trackH,
    required this.rowCount,
    required this.contentMs,
    required this.pxPerMs,
    required this.majorMs,
    required this.minorMs,
  });

  final double width;
  final double height;
  final double rulerH;
  final double trackH;
  final int rowCount;
  final int contentMs;
  final double pxPerMs;
  final int majorMs;
  final int minorMs;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = EditTokens.surfaceHigh;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(6),
      ),
      bg,
    );

    final rulerBg = Paint()..color = const Color(0xFF161B22);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, rulerH), rulerBg);

    final minorPaint = Paint()
      ..color = EditTokens.border.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = EditTokens.textMuted.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final lanePaint = Paint()
      ..color = EditTokens.border.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var ms = 0; ms <= contentMs; ms += minorMs) {
      final x = ms * pxPerMs;
      if (x > width) break;
      final isMajor = ms % majorMs == 0;
      final tickTop = isMajor ? 4.0 : rulerH * 0.45;
      canvas.drawLine(
        Offset(x, tickTop),
        Offset(x, rulerH - 1),
        isMajor ? majorPaint : minorPaint,
      );
      if (isMajor) {
        canvas.drawLine(
          Offset(x, rulerH),
          Offset(x, height),
          Paint()
            ..color = EditTokens.border.withValues(alpha: 0.28)
            ..strokeWidth = 1,
        );
        // Etichette solo ogni major (o ogni 2 se canvas molto lungo).
        final labelEvery = contentMs > 30 * 60 * 1000 ? majorMs * 2 : majorMs;
        if (ms % labelEvery == 0) {
          textPainter.text = TextSpan(
            text: _label(ms),
            style: const TextStyle(
              color: EditTokens.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(x + 3, 3));
        }
      }
    }

    // Separatori tracce (timeline continua, non “card” staccate).
    for (var i = 0; i <= rowCount; i++) {
      final y = rulerH + i * (trackH + 1);
      canvas.drawLine(Offset(0, y), Offset(width, y), lanePaint);
    }
  }

  String _label(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final r = s % 60;
    if (m == 0) return '${r}s';
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter old) =>
      old.width != width ||
      old.height != height ||
      old.contentMs != contentMs ||
      old.majorMs != majorMs ||
      old.rowCount != rowCount;
}

class _TrackLabel extends StatelessWidget {
  const _TrackLabel({
    required this.text,
    required this.height,
    required this.color,
  });

  final String text;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ClipBlock extends StatefulWidget {
  const _ClipBlock({
    super.key,
    required this.clip,
    required this.pxPerMs,
    required this.top,
    required this.height,
    required this.selected,
    required this.isImage,
    required this.hasVolume,
    required this.onTap,
    required this.onDragStart,
    required this.onDragDelta,
    required this.onDragEnd,
    required this.onResizeDuration,
    required this.onResizeEnd,
    required this.onVolume,
  });

  final TimelineClip clip;
  final double pxPerMs;
  final double top;
  final double height;
  final bool selected;
  final bool isImage;
  final bool hasVolume;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragDelta;
  final VoidCallback onDragEnd;
  final ValueChanged<int> onResizeDuration;
  final VoidCallback onResizeEnd;
  final void Function(double volume, {required bool end}) onVolume;

  @override
  State<_ClipBlock> createState() => _ClipBlockState();
}

class _ClipBlockState extends State<_ClipBlock> {
  double _accumDx = 0;
  int? _resizeOriginDur;
  double _volumeDrag = 0;

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final left = clip.timelineStartMs * widget.pxPerMs;
    final width = (clip.durationMs * widget.pxPerMs).clamp(8.0, 100000.0);
    final Color fill;
    final Color border;
    if (widget.selected) {
      fill = EditTokens.accentDim;
      border = EditTokens.accent;
    } else if (clip.trackKind == TrackKind.audio) {
      fill = const Color(0xFF243044);
      border = const Color(0xFF7EB6FF);
    } else if (clip.trackKind == TrackKind.text) {
      fill = const Color(0xFF3A3428);
      border = const Color(0xFFE8C47C);
    } else {
      fill = const Color(0xFF2A3340);
      border = EditTokens.border;
    }

    final label = clip.isCaption
        ? (clip.text?.isNotEmpty == true ? clip.text! : 'Aa')
        : '${(clip.durationMs / 1000).toStringAsFixed(1)}s';

    return Positioned(
      left: left,
      top: widget.top,
      width: width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border, width: widget.selected ? 1.5 : 1),
        ),
        child: Stack(
          children: [
            // Corpo: sposta clip
            Positioned.fill(
              right: 10,
              bottom: widget.hasVolume ? 10 : 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onHorizontalDragStart: (_) {
                  _accumDx = 0;
                  widget.onDragStart();
                },
                onHorizontalDragUpdate: (d) {
                  _accumDx += d.delta.dx;
                  widget.onDragDelta(_accumDx);
                },
                onHorizontalDragEnd: (_) => widget.onDragEnd(),
                onHorizontalDragCancel: widget.onDragEnd,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 4, 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.selected
                            ? EditTokens.accent
                            : EditTokens.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Maniglia destra: durata (immagini / trim)
            Positioned(
              right: 0,
              top: 0,
              bottom: widget.hasVolume ? 10 : 0,
              width: 10,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    _resizeOriginDur = clip.durationMs;
                    _accumDx = 0;
                    widget.onDragStart();
                  },
                  onHorizontalDragUpdate: (d) {
                    _accumDx += d.delta.dx;
                    final origin = _resizeOriginDur ?? clip.durationMs;
                    final next = (origin + _accumDx / widget.pxPerMs)
                        .round()
                        .clamp(200, 30 * 60 * 1000);
                    widget.onResizeDuration(next);
                  },
                  onHorizontalDragEnd: (_) {
                    _resizeOriginDur = null;
                    _accumDx = 0;
                    widget.onResizeEnd();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    child: Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Barra volume in basso
            if (widget.hasVolume)
              Positioned(
                left: 2,
                right: 2,
                bottom: 2,
                height: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onHorizontalDragStart: (_) {
                    _volumeDrag = clip.volume;
                    widget.onDragStart();
                  },
                  onHorizontalDragUpdate: (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    final w = (box?.size.width ?? width) - 4;
                    if (w <= 0) return;
                    _volumeDrag =
                        (_volumeDrag + d.delta.dx / w).clamp(0.0, 1.0);
                    widget.onVolume(_volumeDrag, end: false);
                  },
                  onHorizontalDragEnd: (_) {
                    widget.onVolume(_volumeDrag, end: true);
                  },
                  child: Tooltip(
                    message: 'Volume ${(clip.volume * 100).round()}%',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Container(color: Colors.black26),
                          FractionallySizedBox(
                            widthFactor: clip.volume.clamp(0.0, 1.0),
                            child: Container(
                              color: const Color(0xFF7EB6FF).withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.isImage && widget.selected)
              const Positioned(
                right: 12,
                top: 2,
                child: Icon(Icons.image_outlined, size: 10, color: EditTokens.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _Playhead extends StatefulWidget {
  const _Playhead({
    required this.ms,
    required this.pxPerMs,
    required this.height,
    required this.onDrag,
    required this.onDragEnd,
    required this.maxMs,
  });

  final int ms;
  final double pxPerMs;
  final double height;
  final ValueChanged<int> onDrag;
  final VoidCallback onDragEnd;
  final int maxMs;

  @override
  State<_Playhead> createState() => _PlayheadState();
}

class _PlayheadState extends State<_Playhead> {
  double? _dragX;

  @override
  Widget build(BuildContext context) {
    final x = _dragX ?? (widget.ms * widget.pxPerMs);
    return Positioned(
      left: x - 12,
      top: 0,
      width: 24,
      height: widget.height,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _dragX = widget.ms * widget.pxPerMs;
        },
        onPointerMove: (e) {
          if (_dragX == null) return;
          setState(() {
            _dragX = (_dragX! + e.delta.dx).clamp(0.0, widget.maxMs * widget.pxPerMs);
          });
          final ms = (_dragX! / widget.pxPerMs).round().clamp(0, widget.maxMs);
          widget.onDrag(ms);
        },
        onPointerUp: (_) {
          _dragX = null;
          widget.onDragEnd();
        },
        onPointerCancel: (_) {
          _dragX = null;
          widget.onDragEnd();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  color: EditTokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(width: 2, color: EditTokens.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
