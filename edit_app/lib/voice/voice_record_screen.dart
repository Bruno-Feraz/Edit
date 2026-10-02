import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../theme/tokens.dart';

/// Risultato registrazione: path file + durata stimata.
class VoiceRecordingResult {
  const VoiceRecordingResult({
    required this.tempPath,
    required this.durationMs,
  });

  final String tempPath;
  final int durationMs;
}

/// Schermata dedicata: registra voice-over (mic → file temporaneo).
class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({super.key});

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen> {
  final _recorder = AudioRecorder();
  final _uuid = const Uuid();

  bool _recording = false;
  bool _hasTake = false;
  String? _path;
  int _elapsedMs = 0;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    final ok = await _recorder.hasPermission();
    if (!ok) {
      setState(() => _error = 'Permesso microfono negato');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'vo_${_uuid.v4()}.m4a');

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
    } catch (e) {
      setState(() => _error = 'Impossibile avviare: $e');
      return;
    }

    _path = path;
    _elapsedMs = 0;
    _hasTake = false;
    _recording = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs += 200);
    });
    setState(() {});
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    _recording = false;
    if (path != null) {
      _path = path;
      _hasTake = true;
    }
    setState(() {});
  }

  Future<void> _discard() async {
    if (_recording) await _stop();
    final path = _path;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    setState(() {
      _path = null;
      _hasTake = false;
      _elapsedMs = 0;
    });
  }

  void _confirm() {
    final path = _path;
    if (path == null || !_hasTake) return;
    Navigator.of(context).pop(
      VoiceRecordingResult(
        tempPath: path,
        durationMs: _elapsedMs.clamp(200, 1 << 30),
      ),
    );
  }

  String _fmt(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final r = s % 60;
    final frac = ((ms % 1000) / 100).floor();
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}.$frac';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registra voice-over'),
        actions: [
          if (_hasTake && !_recording)
            TextButton(
              onPressed: _discard,
              child: const Text('Scarta'),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(EditTokens.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _recording
                          ? EditTokens.danger.withValues(alpha: 0.15)
                          : EditTokens.surfaceHigh,
                      border: Border.all(
                        color: _recording
                            ? EditTokens.danger
                            : EditTokens.border,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _recording ? Icons.mic : Icons.mic_none,
                      size: 48,
                      color: _recording
                          ? EditTokens.danger
                          : EditTokens.accent,
                    ),
                  ),
                  const SizedBox(height: EditTokens.spaceLg),
                  Text(
                    _fmt(_elapsedMs),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(height: EditTokens.spaceSm),
                  Text(
                    _recording
                        ? 'Registrazione in corso…'
                        : (_hasTake
                            ? 'Take pronto — salva sulla timeline'
                            : 'Premi per registrare'),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: EditTokens.spaceMd),
                    Text(
                      _error!,
                      style: const TextStyle(color: EditTokens.danger),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: EditTokens.spaceXl),
                  if (!_recording && !_hasTake)
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.fiber_manual_record, size: 18),
                      label: const Text('Registra'),
                    ),
                  if (_recording)
                    FilledButton.icon(
                      onPressed: _stop,
                      style: FilledButton.styleFrom(
                        backgroundColor: EditTokens.danger,
                        foregroundColor: EditTokens.text,
                      ),
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('Stop'),
                    ),
                  if (_hasTake && !_recording) ...[
                    FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Usa sulla timeline'),
                    ),
                    const SizedBox(height: EditTokens.spaceSm),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _discard();
                        await _start();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Riregistra'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
