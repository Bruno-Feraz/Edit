import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../brand/edit_logo.dart';
import '../models/project.dart';
import '../services/project_store.dart';
import '../theme/tokens.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final ProjectStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<EditProject>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = widget.store.listProjects();
    });
  }

  Future<void> _create() async {
    final project = await widget.store.createProject();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(store: widget.store, project: project),
      ),
    );
    _reload();
  }

  Future<void> _open(EditProject project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(store: widget.store, project: project),
      ),
    );
    _reload();
  }

  Future<void> _confirmDelete(EditProject project) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare il progetto?'),
        content: Text(
          '“${project.name}” verrà rimosso dal dispositivo. Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: EditTokens.danger),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.deleteProject(project.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EditTokens.spaceLg,
                vertical: EditTokens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onNew: _create),
                  const SizedBox(height: EditTokens.spaceLg),
                  Expanded(
                    child: FutureBuilder<List<EditProject>>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final projects = snap.data ?? [];
                        if (projects.isEmpty) {
                          return _EmptyState(onNew: _create);
                        }
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow =
                                constraints.maxWidth < EditTokens.breakpointNarrow;
                            if (narrow) {
                              return ListView.separated(
                                itemCount: projects.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: EditTokens.spaceSm),
                                itemBuilder: (context, i) => _ProjectTile(
                                  project: projects[i],
                                  onTap: () => _open(projects[i]),
                                  onDelete: () => _confirmDelete(projects[i]),
                                ),
                              );
                            }
                            return GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 280,
                                mainAxisSpacing: EditTokens.spaceMd,
                                crossAxisSpacing: EditTokens.spaceMd,
                                childAspectRatio: 1.35,
                              ),
                              itemCount: projects.length,
                              itemBuilder: (context, i) => _ProjectCard(
                                project: projects[i],
                                onTap: () => _open(projects[i]),
                                onDelete: () => _confirmDelete(projects[i]),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        final title = Row(
          children: [
            const EditLogo(size: 36),
            const SizedBox(width: 12),
            Text('Edit', style: Theme.of(context).textTheme.titleLarge),
          ],
        );
        final button = FilledButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuovo progetto'),
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: EditTokens.spaceSm),
              Text(
                'Progetti sul dispositivo',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: EditTokens.spaceMd),
              button,
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 2),
                  Text(
                    'Progetti sul dispositivo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            button,
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EditLogo(size: 72),
            const SizedBox(height: EditTokens.spaceMd),
            Text(
              'Nessun progetto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: EditTokens.spaceSm),
            Text(
              'Crea un progetto 9:16 e inizia a tagliare clip.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: EditTokens.spaceLg),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuovo progetto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  final EditProject project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy, HH:mm').format(project.updatedAt);
    return Material(
      color: EditTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EditTokens.radiusMd),
        side: const BorderSide(color: EditTokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(EditTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: EditTokens.surfaceHigh,
                    borderRadius: BorderRadius.circular(EditTokens.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    project.aspect.label,
                    style: const TextStyle(
                      color: EditTokens.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: EditTokens.spaceMd),
              Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(date, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  final EditProject project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM, HH:mm').format(project.updatedAt);
    return Material(
      color: EditTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EditTokens.radiusMd),
        side: const BorderSide(color: EditTokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: EditTokens.spaceMd,
          vertical: EditTokens.spaceXs,
        ),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EditTokens.surfaceHigh,
            borderRadius: BorderRadius.circular(EditTokens.radiusSm),
          ),
          child: Text(
            project.aspect.label,
            style: const TextStyle(
              color: EditTokens.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(date),
        trailing: IconButton(
          tooltip: 'Elimina',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 20),
        ),
      ),
    );
  }
}
