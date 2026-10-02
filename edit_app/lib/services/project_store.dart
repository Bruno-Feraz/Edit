import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/project.dart';

/// Persistenza locale progetti in sandbox app.
///
/// Struttura:
///   `{docs}/Edit/projects/{id}/project.json`
///   `{docs}/Edit/projects/{id}/media/`
class ProjectStore {
  ProjectStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  Directory? _root;

  Future<Directory> _projectsRoot() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/Edit/projects');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _root = root;
    return root;
  }

  Future<Directory> projectDir(String id) async {
    final root = await _projectsRoot();
    return Directory('${root.path}/$id');
  }

  Future<File> _projectFile(String id) async {
    final dir = await projectDir(id);
    return File('${dir.path}/project.json');
  }

  Future<List<EditProject>> listProjects() async {
    final root = await _projectsRoot();
    if (!await root.exists()) return [];

    final projects = <EditProject>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final file = File('${entity.path}/project.json');
      if (!await file.exists()) continue;
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        projects.add(EditProject.fromJson(json));
      } catch (_) {
        // Progetto corrotto: salta, non crashare la home.
      }
    }

    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<EditProject> createProject({
    String? name,
    AspectPreset aspect = AspectPreset.vertical916,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final project = EditProject(
      id: id,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : 'Progetto ${_shortDate(now)}',
      createdAt: now,
      updatedAt: now,
      aspect: aspect,
    );

    final dir = await projectDir(id);
    await dir.create(recursive: true);
    await Directory('${dir.path}/media').create(recursive: true);
    await saveProject(project);
    return project;
  }

  Future<EditProject?> loadProject(String id) async {
    final file = await _projectFile(id);
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return EditProject.fromJson(json);
  }

  Future<void> saveProject(EditProject project) async {
    project.updatedAt = DateTime.now();
    final file = await _projectFile(project.id);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(project.toJson()));
  }

  Future<void> renameProject(EditProject project, String name) async {
    project.name = name.trim().isEmpty ? project.name : name.trim();
    await saveProject(project);
  }

  Future<void> deleteProject(String id) async {
    final dir = await projectDir(id);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  String _shortDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$day/$m';
  }
}
