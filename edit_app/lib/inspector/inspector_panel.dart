import 'package:flutter/material.dart';

import '../editor/editor_controller.dart';
import '../models/project.dart';
import '../models/timeline_clip.dart';
import '../services/media_pick_helper.dart';
import '../theme/tokens.dart';
import '../voice/voice_record_screen.dart';

/// Pannello destro dinamico: cambia sezione (media, audio, effetti…).
class InspectorPanel extends StatelessWidget {
  const InspectorPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.inspectorOpen) {
          return const SizedBox.shrink();
        }
        return Container(
          width: 280,
          decoration: const BoxDecoration(
            color: EditTokens.surface,
            border: Border(left: BorderSide(color: EditTokens.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTabs(controller: controller),
              const Divider(height: 1, color: EditTokens.border),
              Expanded(child: _SectionBody(controller: controller)),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    Widget tab(InspectorSection s, IconData icon, String label) {
      final on = controller.inspectorSection == s;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => controller.setInspectorSection(s),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: on ? EditTokens.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: on ? EditTokens.accent : EditTokens.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? EditTokens.accent : EditTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  tab(InspectorSection.media, Icons.perm_media_outlined, 'Media'),
                  tab(InspectorSection.audio, Icons.graphic_eq, 'Audio'),
                  tab(InspectorSection.cleanAudio, Icons.hearing_outlined, 'Pulisci'),
                  tab(InspectorSection.text, Icons.title, 'Testo'),
                  tab(InspectorSection.enhance, Icons.tune, 'Enhance'),
                  tab(InspectorSection.removeBg, Icons.person_outline, 'Sfondo'),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Chiudi',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            onPressed: controller.toggleInspector,
            icon: const Icon(Icons.close, color: EditTokens.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.inspectorSection) {
      case InspectorSection.media:
        return _MediaSection(controller: controller);
      case InspectorSection.audio:
        return _AudioSection(controller: controller);
      case InspectorSection.text:
        return _TextSection(controller: controller);
      case InspectorSection.removeBg:
        return _RemoveBgSection(controller: controller);
      case InspectorSection.enhance:
        return _EnhanceSection(controller: controller);
      case InspectorSection.cleanAudio:
        return _DenoiseSection(controller: controller);
    }
  }
}

class _MediaSection extends StatelessWidget {
  const _MediaSection({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final media = controller.project.media;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('Libreria', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Aggiungi'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text('Traccia video', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: controller.targetVideoTrack,
                dropdownColor: EditTokens.surfaceHigh,
                underline: const SizedBox.shrink(),
                items: List.generate(
                  controller.project.timeline.videoTrackCount,
                  (i) => DropdownMenuItem(value: i, child: Text('V${i + 1}')),
                ),
                onChanged: (v) {
                  if (v == null) return;
                  controller.setTargetVideoTrack(v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: media.isEmpty
              ? Center(
                  child: Text(
                    'Nessun file.\nImporta video o immagini.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: media.length,
                  itemBuilder: (context, i) {
                    final m = media[i];
                    return _MediaTile(
                      media: m,
                      onPlace: () => controller.placeMediaOnTimeline(m),
                      onTap: () => _mediaMenu(context, m),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _import(BuildContext context) async {
    await pickAndImportPhotoVideo(context, controller);
  }

  Future<void> _mediaMenu(BuildContext context, MediaRef m) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: EditTokens.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(m.kind.name),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Metti su timeline'),
              onTap: () {
                Navigator.pop(ctx);
                controller.placeMediaOnTimeline(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                m.durationMs != null
                    ? 'Durata ${(m.durationMs! / 1000).toStringAsFixed(1)}s'
                    : 'Durata n/d',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.media,
    required this.onPlace,
    required this.onTap,
  });

  final MediaRef media;
  final VoidCallback onPlace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (media.kind) {
      case MediaKind.video:
        icon = Icons.movie_outlined;
      case MediaKind.image:
        icon = Icons.image_outlined;
      case MediaKind.audio:
        icon = Icons.audiotrack;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: EditTokens.accent, size: 20),
        title: Text(
          media.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          media.kind.name,
          style: const TextStyle(fontSize: 11, color: EditTokens.textMuted),
        ),
        trailing: IconButton(
          tooltip: 'Su timeline',
          icon: const Icon(Icons.add, size: 18),
          onPressed: onPlace,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _AudioSection extends StatelessWidget {
  const _AudioSection({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final n = controller.project.timeline.audioTrackCount;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Audio', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Tracce audio: $n (base A1–A2). Aggiungi tracce o importa VO.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Destinazione', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: controller.targetAudioTrack.clamp(0, n - 1),
              dropdownColor: EditTokens.surfaceHigh,
              underline: const SizedBox.shrink(),
              items: List.generate(
                n,
                (i) => DropdownMenuItem(value: i, child: Text('A${i + 1}')),
              ),
              onChanged: (v) {
                if (v == null) return;
                controller.setTargetAudioTrack(v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _importAudio(context),
          icon: const Icon(Icons.file_upload_outlined, size: 18),
          label: const Text('Importa audio'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.addAudioTrack,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuova traccia audio'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openVoice(context),
          icon: const Icon(Icons.mic_none, size: 18),
          label: const Text('Registra voice-over'),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1, color: EditTokens.border),
        const SizedBox(height: 16),
        Text('Pulisci audio', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Riduce rumore sul clip selezionato (audio o video).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        _DenoiseAction(controller: controller),
        TextButton(
          onPressed: () =>
              controller.setInspectorSection(InspectorSection.cleanAudio),
          child: const Text('Apri sezione Pulisci →'),
        ),
        if (controller.selectedClip?.trackKind == TrackKind.audio) ...[
          const SizedBox(height: 8),
          Text('Volume clip', style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: controller.selectedClip!.volume,
            onChanged: (v) =>
                controller.setClipVolume(v, recordHistory: false),
            onChangeEnd: (v) => controller.setClipVolume(v),
          ),
        ],
        const SizedBox(height: 16),
        Text('Clip audio in timeline',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...controller.project.timeline.audioClips.map((c) {
          final m = controller.project.mediaById(c.mediaId);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.audiotrack, size: 18),
            title: Text(
              m?.label ?? c.id.substring(0, 8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text('A${c.trackIndex + 1} · ${_fmt(c.durationMs)}'),
            onTap: () => controller.selectClip(c.id),
          );
        }),
      ],
    );
  }

  Future<void> _importAudio(BuildContext context) async {
    await pickAndImportAudio(context, controller);
  }

  Future<void> _openVoice(BuildContext context) async {
    final result = await Navigator.of(context).push<VoiceRecordingResult>(
      MaterialPageRoute(builder: (_) => const VoiceRecordScreen()),
    );
    if (result == null) return;
    try {
      await controller.attachVoiceRecording(
        tempPath: result.tempPath,
        durationMs: result.durationMs,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice-over aggiunto in timeline')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _fmt(int ms) => '${(ms / 1000).toStringAsFixed(1)}s';
}

class _TextSection extends StatefulWidget {
  const _TextSection({required this.controller});

  final EditorController controller;

  @override
  State<_TextSection> createState() => _TextSectionState();
}

class _TextSectionState extends State<_TextSection> {
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(
      text: widget.controller.selectedClip?.isCaption == true
          ? (widget.controller.selectedClip!.text ?? '')
          : '',
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selected = widget.controller.selectedClip;
        final editingCaption = selected?.isCaption == true;
        if (editingCaption && _textCtrl.text != (selected!.text ?? '')) {
          _textCtrl.text = selected.text ?? '';
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Testo parlato', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Caption sulla traccia T1. Posizione = playhead.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => widget.controller.addCaption(),
              icon: const Icon(Icons.title, size: 18),
              label: const Text('Aggiungi caption'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await widget.controller.generateAutoCaptions();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sottotitoli generati (modificabili su T1)'),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Genera dall’audio'),
            ),
            if (editingCaption) ...[
              const SizedBox(height: 16),
              Text('Modifica', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              TextField(
                controller: _textCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Testo in sovrimpressione',
                ),
                onChanged: (v) => widget.controller.updateCaptionText(v),
              ),
              const SizedBox(height: 12),
              Text('Animazione testo',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: TextMotion.values.map((m) {
                  final on = selected!.textMotion == m;
                  return ChoiceChip(
                    label: Text(_textMotionLabel(m)),
                    selected: on,
                    onSelected: (_) => widget.controller.setTextMotion(m),
                    selectedColor: EditTokens.accentDim,
                    labelStyle: TextStyle(
                      color: on ? EditTokens.accent : EditTokens.textMuted,
                      fontSize: 11,
                    ),
                    backgroundColor: EditTokens.surfaceHigh,
                    side: BorderSide(
                      color: on ? EditTokens.accent : EditTokens.border,
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Durata ${(selected!.durationMs / 1000).toStringAsFixed(1)}s · trim dalla toolbar',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Text('Caption in timeline',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ...widget.controller.project.timeline.textClips.map((c) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.title, size: 18),
                title: Text(
                  c.text?.isNotEmpty == true ? c.text! : '(vuoto)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '${(c.durationMs / 1000).toStringAsFixed(1)}s @ ${(c.timelineStartMs / 1000).toStringAsFixed(1)}s',
                ),
                onTap: () => widget.controller.selectClip(c.id),
              );
            }),
          ],
        );
      },
    );
  }

  String _textMotionLabel(TextMotion m) {
    switch (m) {
      case TextMotion.none:
        return 'Nessuna';
      case TextMotion.fadeIn:
        return 'Fade';
      case TextMotion.slideUp:
        return 'Slide ↑';
      case TextMotion.slideDown:
        return 'Slide ↓';
    }
  }
}

class _RemoveBgSection extends StatelessWidget {
  const _RemoveBgSection({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final clip = controller.selectedClip;
    final media =
        clip != null ? controller.project.mediaById(clip.mediaId) : null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Rimuovi sfondo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Seleziona un clip immagine o video in timeline, poi avvia. '
          'Serve rembg o backgroundremover nel PATH (pip install rembg).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (media != null)
          Text(
            'Selezionato: ${media.label} (${media.kind.name})'
            '${clip!.backgroundRemoved ? ' · già senza sfondo' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Text(
            'Nessun clip media selezionato.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.isBusy
              ? null
              : () async {
                  try {
                    await controller.removeBackgroundOnSelected();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sfondo rimosso')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
          child: Text(controller.isBusy ? 'Elaboro…' : 'Rimuovi sfondo'),
        ),
        const SizedBox(height: 16),
        Text('Animazione immagine',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ImageMotion.values.map((m) {
            final on = clip?.imageMotion == m;
            return ChoiceChip(
              label: Text(_imgMotionLabel(m)),
              selected: on,
              onSelected: clip == null
                  ? null
                  : (_) => controller.setImageMotion(m),
              selectedColor: EditTokens.accentDim,
              labelStyle: TextStyle(
                color: on ? EditTokens.accent : EditTokens.textMuted,
                fontSize: 11,
              ),
              backgroundColor: EditTokens.surfaceHigh,
              side: BorderSide(
                color: on ? EditTokens.accent : EditTokens.border,
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  String _imgMotionLabel(ImageMotion m) {
    switch (m) {
      case ImageMotion.none:
        return 'Nessuna';
      case ImageMotion.kenBurnsIn:
        return 'Zoom in';
      case ImageMotion.kenBurnsOut:
        return 'Zoom out';
      case ImageMotion.panLeft:
        return 'Pan →';
      case ImageMotion.panRight:
        return 'Pan ←';
    }
  }
}

class _EnhanceSection extends StatelessWidget {
  const _EnhanceSection({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final clip = controller.selectedClip;
        if (clip == null || clip.isCaption) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Seleziona un clip video o immagine per regolare luminosità, contrasto e saturazione.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Enhance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Anteprima in play; l’export applica i valori con FFmpeg.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Luminosità', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: clip.brightness,
              min: -0.5,
              max: 0.5,
              onChanged: (v) =>
                  controller.setEnhance(brightness: v, recordHistory: false),
              onChangeEnd: (v) => controller.setEnhance(brightness: v),
            ),
            Text('Contrasto', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: clip.contrast,
              min: 0.5,
              max: 1.8,
              onChanged: (v) =>
                  controller.setEnhance(contrast: v, recordHistory: false),
              onChangeEnd: (v) => controller.setEnhance(contrast: v),
            ),
            Text('Saturazione', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: clip.saturation,
              min: 0,
              max: 2,
              onChanged: (v) =>
                  controller.setEnhance(saturation: v, recordHistory: false),
              onChangeEnd: (v) => controller.setEnhance(saturation: v),
            ),
            TextButton(
              onPressed: controller.resetEnhance,
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}

class _DenoiseSection extends StatelessWidget {
  const _DenoiseSection({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final clip = controller.selectedClip;
    final media = clip != null ? controller.project.mediaById(clip.mediaId) : null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Pulisci audio', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Riduce rumore sul clip selezionato (FFmpeg afftdn / filtri). '
          'Crea un nuovo file media senza tenere l’audio intero in RAM.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (clip == null)
          Text(
            'Seleziona un clip audio o video sulla timeline.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: EditTokens.textMuted,
                ),
          )
        else
          Text(
            'Clip: ${media?.label ?? clip.id.substring(0, 8)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 16),
        _DenoiseAction(controller: controller),
      ],
    );
  }
}

class _DenoiseAction extends StatelessWidget {
  const _DenoiseAction({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: controller.isBusy
          ? null
          : () async {
              try {
                await controller.denoiseSelected();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio pulito')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$e')));
              }
            },
      icon: const Icon(Icons.hearing, size: 18),
      label: Text(controller.isBusy ? 'Elaboro…' : 'Pulisci clip selezionato'),
    );
  }
}
