import 'package:flutter/material.dart';

import '../editor/editor_controller.dart';
import '../help/help_screen.dart';
import '../services/media_pick_helper.dart';
import '../theme/tokens.dart';
import '../voice/voice_record_screen.dart';

/// Bottoni piccoli di montaggio — sopra la timeline (non a destra).
class TimelineActionBar extends StatelessWidget {
  const TimelineActionBar({
    super.key,
    required this.controller,
    this.onExport,
  });

  final EditorController controller;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          height: 44,
          decoration: const BoxDecoration(
            color: EditTokens.surface,
            border: Border(
              top: BorderSide(color: EditTokens.border),
              bottom: BorderSide(color: EditTokens.border),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _IconBtn(
                tip: 'Play / Pausa',
                icon: controller.isPlaying ? Icons.pause : Icons.play_arrow,
                onTap: controller.togglePlay,
              ),
              _IconBtn(
                tip: 'Importa',
                icon: Icons.file_upload_outlined,
                onTap: () => _importMenu(context),
              ),
              _IconBtn(
                tip: 'Caption',
                icon: Icons.title,
                onTap: () {
                  controller.addCaption();
                  controller.setInspectorSection(InspectorSection.text);
                },
              ),
              _IconBtn(
                tip: 'Voice-over',
                icon: Icons.mic_none,
                onTap: () => _voice(context),
              ),
              _IconBtn(
                tip: 'Pulisci audio',
                icon: Icons.hearing_outlined,
                onTap: () {
                  controller.setInspectorSection(InspectorSection.cleanAudio);
                },
              ),
              _IconBtn(
                tip: 'Spezza (B)',
                icon: Icons.content_cut,
                onTap: controller.splitAtPlayhead,
              ),
              _IconBtn(
                tip: 'Trim +0.5s inizio',
                icon: Icons.skip_previous,
                onTap: () {
                  final c = controller.selectedClip;
                  if (c == null) return;
                  controller.trimSelected(newSourceStart: c.sourceStartMs + 500);
                },
              ),
              _IconBtn(
                tip: 'Trim −0.5s fine',
                icon: Icons.skip_next,
                onTap: () {
                  final c = controller.selectedClip;
                  if (c == null) return;
                  controller.trimSelected(newSourceEnd: c.sourceEndMs - 500);
                },
              ),
              _IconBtn(
                tip: 'Elimina clip',
                icon: Icons.delete_outline,
                danger: true,
                onTap: controller.deleteSelected,
              ),
              const VerticalDivider(width: 16, color: EditTokens.border),
              _IconBtn(
                tip: 'Annulla',
                icon: Icons.undo,
                onTap: controller.canUndo ? controller.undo : null,
              ),
              _IconBtn(
                tip: 'Ripeti',
                icon: Icons.redo,
                onTap: controller.canRedo ? controller.redo : null,
              ),
              const Spacer(),
              if (controller.statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    controller.statusMessage!,
                    style: const TextStyle(
                      color: EditTokens.accent,
                      fontSize: 11,
                    ),
                  ),
                ),
              _IconBtn(
                tip: 'Guida',
                icon: Icons.help_outline,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  );
                },
              ),
              _IconBtn(
                tip: 'Esporta / Condividi',
                icon: Icons.ios_share,
                onTap: onExport == null ||
                        controller.isBusy ||
                        controller.project.timeline.videoClips.isEmpty
                    ? null
                    : onExport,
              ),
              _IconBtn(
                tip: 'Pannello destro',
                icon: controller.inspectorOpen
                    ? Icons.view_sidebar
                    : Icons.view_sidebar_outlined,
                onTap: controller.toggleInspector,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importMenu(BuildContext context) async {
    final choice = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(80, 120, 0, 0),
      color: EditTokens.surfaceHigh,
      items: const [
        PopupMenuItem(value: 'video', child: Text('Video / immagine')),
        PopupMenuItem(value: 'audio', child: Text('Audio')),
      ],
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'audio') {
      await pickAndImportAudio(context, controller);
      return;
    }
    await pickAndImportPhotoVideo(context, controller);
  }

  Future<void> _voice(BuildContext context) async {
    final result = await Navigator.of(context).push<VoiceRecordingResult>(
      MaterialPageRoute(builder: (_) => const VoiceRecordScreen()),
    );
    if (result == null) return;
    try {
      await controller.attachVoiceRecording(
        tempPath: result.tempPath,
        durationMs: result.durationMs,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.tip,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String tip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? EditTokens.textMuted.withValues(alpha: 0.35)
        : (danger ? EditTokens.danger : EditTokens.text);
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
