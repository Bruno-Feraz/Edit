import '../models/timeline_clip.dart';

/// Risultato snap: posizione e, se presente, guida verticale da evidenziare.
class SnapResult {
  const SnapResult({required this.ms, this.guideMs});

  final int ms;
  final int? guideMs;
}

/// Magnetismo timeline: allinea start/end clip (anche tra tracce diverse).
class TimelineSnap {
  TimelineSnap._();

  /// Soglia tipica ~12px → ms.
  static int thresholdMs(double pxPerMs, {double px = 12}) =>
      (px / pxPerMs).round().clamp(40, 800);

  static int majorTickMs(double pxPerMs) {
    const candidates = [
      100,
      200,
      500,
      1000,
      2000,
      5000,
      10000,
      15000,
      30000,
      60000,
    ];
    for (final c in candidates) {
      if (c * pxPerMs >= 56) return c;
    }
    return 60000;
  }

  static int minorTickMs(int major) {
    if (major >= 10000) return major ~/ 5;
    if (major >= 1000) return major ~/ 4;
    return major ~/ 2;
  }

  /// Snap playhead a tacche e bordi clip.
  static SnapResult snapPlayhead({
    required int proposedMs,
    required List<TimelineClip> clips,
    required double pxPerMs,
    int? maxMs,
  }) {
    final thr = thresholdMs(pxPerMs);
    final targets = <int>{0};
    final major = majorTickMs(pxPerMs);
    final minor = minorTickMs(major);
    final limit = maxMs ?? proposedMs + major * 4;
    for (var t = 0; t <= limit + major; t += minor) {
      targets.add(t);
    }
    for (final c in clips) {
      targets.add(c.timelineStartMs);
      targets.add(c.timelineEndMs);
    }
    return _nearest(proposedMs, targets, thr);
  }

  /// Snap start clip: start/end di altri clip + playhead + 0.
  /// Preferisce allineamento start↔start tra tracce diverse.
  static SnapResult snapClipStart({
    required int proposedStart,
    required int durationMs,
    required String clipId,
    required List<TimelineClip> clips,
    required int playheadMs,
    required double pxPerMs,
  }) {
    final thr = thresholdMs(pxPerMs, px: 14);
    final startTargets = <int>{0, playheadMs};
    final endTargets = <int>{0, playheadMs};

    for (final c in clips) {
      if (c.id == clipId) continue;
      startTargets.add(c.timelineStartMs);
      startTargets.add(c.timelineEndMs);
      endTargets.add(c.timelineStartMs);
      endTargets.add(c.timelineEndMs);
    }

    // Priorità: start allineato ad altri start (soprattutto altre tracce).
    final sameStartPref = <int>{};
    for (final c in clips) {
      if (c.id == clipId) continue;
      sameStartPref.add(c.timelineStartMs);
    }
    final prefer = _nearest(proposedStart, sameStartPref, thr);
    if (prefer.guideMs != null) return prefer;

    final byStart = _nearest(proposedStart, startTargets, thr);
    final proposedEnd = proposedStart + durationMs;
    final byEnd = _nearest(proposedEnd, endTargets, thr);
    if (byEnd.guideMs != null) {
      final snappedStart = byEnd.ms - durationMs;
      if (byStart.guideMs == null ||
          (proposedEnd - byEnd.guideMs!).abs() <=
              (proposedStart - byStart.guideMs!).abs()) {
        return SnapResult(ms: snappedStart.clamp(0, 1 << 30), guideMs: byEnd.guideMs);
      }
    }
    return SnapResult(
      ms: byStart.ms.clamp(0, 1 << 30),
      guideMs: byStart.guideMs,
    );
  }

  static SnapResult _nearest(int value, Iterable<int> targets, int thr) {
    int? best;
    var bestDist = thr + 1;
    for (final t in targets) {
      final d = (value - t).abs();
      if (d <= thr && d < bestDist) {
        best = t;
        bestDist = d;
      }
    }
    if (best == null) return SnapResult(ms: value);
    return SnapResult(ms: best, guideMs: best);
  }
}
