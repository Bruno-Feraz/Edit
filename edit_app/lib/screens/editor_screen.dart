import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../editor/editor_controller.dart';
import '../help/help_screen.dart';
import '../inspector/inspector_panel.dart';
import '../models/project.dart';
import '../models/social_export_preset.dart';
import '../preview/video_preview_pane.dart';
import '../services/project_store.dart';
import '../theme/tokens.dart';
import '../timeline/timeline_panel.dart';
import '../tools/timeline_action_bar.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.store,
    required this.project,
  });

  final ProjectStore store;
  final EditProject project;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        EditorController(store: widget.store, project: widget.project);
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: _controller.project.name);
        return AlertDialog(
          title: const Text('Rinomina'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nome progetto'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
    if (name == null) return;
    await _controller.rename(name);
  }

  Future<void> _export() async {
    final preset = await showModalBottomSheet<SocialExportPreset?>(
      context: context,
      backgroundColor: EditTokens.surface,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Esporta per',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...SocialExportPreset.values.map(
                (p) => ListTile(
                  leading: const Icon(Icons.high_quality_outlined),
                  title: Text(p.label),
                  subtitle: Text(p.detail),
                  onTap: () => Navigator.pop(ctx, p),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text('Formato progetto (senza ridimensionare)'),
                onTap: () => Navigator.pop(ctx, null),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    // null from dismiss vs explicit "senza ridimensionare":
    // bottom sheet returns null on dismiss AND on last tile — OK same path.
    if (!mounted) return;
    // If user dismissed by tapping outside, also null — proceed with project format.
    try {
      final result = await _controller.export(social: preset);
      if (!mounted) return;
      final share = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export pronto'),
          content: Text(result.outputPath),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Chiudi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Condividi'),
            ),
          ],
        ),
      );
      if (share == true && mounted) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(result.outputPath)]),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _aspectMenu() async {
    final choice = await showMenu<AspectPreset>(
      context: context,
      position: const RelativeRect.fromLTRB(200, 56, 0, 0),
      color: EditTokens.surfaceHigh,
      items: AspectPreset.values
          .map(
            (p) => PopupMenuItem(
              value: p,
              child: Text(p.label),
            ),
          )
          .toList(),
    );
    if (choice == null) return;
    await _controller.setAspect(choice);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            _controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _controller.redo,
        const SingleActivator(LogicalKeyboardKey.space): _controller.togglePlay,
        const SingleActivator(LogicalKeyboardKey.keyB):
            _controller.splitAtPlayhead,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return GestureDetector(
                  onTap: _rename,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _controller.project.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: EditTokens.textMuted,
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                tooltip: 'Guida',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  );
                },
                icon: const Icon(Icons.help_outline),
              ),
              TextButton(
                onPressed: _aspectMenu,
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (_, __) => Text(_controller.project.aspect.label),
                ),
              ),
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  return Padding(
                    padding: const EdgeInsets.only(right: EditTokens.spaceSm),
                    child: FilledButton(
                      onPressed: _controller.isBusy ||
                              _controller.project.timeline.videoClips.isEmpty
                          ? null
                          : _export,
                      child: Text(_controller.isBusy ? '…' : 'Esporta'),
                    ),
                  );
                },
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final narrow =
                  constraints.maxWidth < EditTokens.breakpointNarrow;
              final preview = VideoPreviewPane(controller: _controller);
              final actionBar = TimelineActionBar(
                controller: _controller,
                onExport: _export,
              );
              final timeline = TimelinePanel(controller: _controller);
              final inspector = InspectorPanel(controller: _controller);

              final bottom = Column(
                children: [
                  actionBar,
                  Expanded(child: timeline),
                ],
              );

              if (narrow) {
                return Column(
                  children: [
                    Expanded(flex: 4, child: preview),
                    Expanded(flex: 5, child: bottom),
                    ListenableBuilder(
                      listenable: _controller,
                      builder: (_, __) {
                        if (!_controller.inspectorOpen) {
                          return const SizedBox.shrink();
                        }
                        return SizedBox(
                          height: constraints.maxHeight * 0.35,
                          child: inspector,
                        );
                      },
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(
                    flex: 5,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: preview),
                        inspector,
                      ],
                    ),
                  ),
                  Expanded(flex: 4, child: bottom),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
