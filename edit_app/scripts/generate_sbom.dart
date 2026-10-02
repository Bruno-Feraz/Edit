#!/usr/bin/env dart
// Genera SBOM CycloneDX 1.5 (JSON) dalle dipendenze in pubspec.lock.
// Uso: dalla cartella edit_app → dart run scripts/generate_sbom.dart
// Output: release/sbom-<version>-<yyyymmdd>.cdx.json

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = Directory.current;
  final lockFile = File('${root.path}/pubspec.lock');
  final pubspecFile = File('${root.path}/pubspec.yaml');
  if (!lockFile.existsSync()) {
    stderr.writeln('pubspec.lock non trovato in ${root.path}');
    exit(1);
  }

  final pubspec = pubspecFile.readAsStringSync();
  final versionMatch =
      RegExp(r'^version:\s*([^\s]+)', multiLine: true).firstMatch(pubspec);
  final appVersion = versionMatch?.group(1) ?? '0.0.0';

  final lock = lockFile.readAsStringSync();
  final packages = <Map<String, dynamic>>[];
  final blockRe = RegExp(
    r'^  ([a-zA-Z0-9_]+):\n((?:    .*\n)+)',
    multiLine: true,
  );

  for (final m in blockRe.allMatches(lock)) {
    final name = m.group(1)!;
    if (name == 'sdks') continue;
    final body = m.group(2)!;
    final depLine = RegExp(r'dependency:\s*"?([^"\n]+)"?').firstMatch(body);
    final verLine = RegExp(r'version:\s*"([^"]+)"').firstMatch(body);
    final shaLine = RegExp(r'sha256:\s*"?([a-f0-9]+)"?').firstMatch(body);
    final urlLine = RegExp(r'url:\s*"([^"]+)"').firstMatch(body);
    if (verLine == null) continue;

    final dependency = depLine?.group(1)?.trim() ?? 'transitive';
    final version = verLine.group(1)!;
    final component = <String, dynamic>{
      'type': 'library',
      'name': name,
      'version': version,
      'bom-ref': 'pkg:pub/$name@$version',
      'purl': 'pkg:pub/$name@$version',
      'properties': [
        {'name': 'pub.dependency', 'value': dependency},
      ],
    };
    if (shaLine != null) {
      component['hashes'] = [
        {'alg': 'SHA-256', 'content': shaLine.group(1)},
      ];
    }
    if (urlLine != null) {
      component['externalReferences'] = [
        {'type': 'distribution', 'url': urlLine.group(1)},
      ];
    }
    packages.add(component);
  }

  packages.sort(
    (a, b) => (a['name'] as String).compareTo(b['name'] as String),
  );

  final now = DateTime.now().toUtc();
  final stamp =
      '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final bom = {
    'bomFormat': 'CycloneDX',
    'specVersion': '1.5',
    'version': 1,
    'metadata': {
      'timestamp': now.toIso8601String(),
      'component': {
        'type': 'application',
        'name': 'Edit',
        'version': appVersion,
        'bom-ref': 'pkg:pub/edit_app@$appVersion',
      },
      'tools': [
        {
          'vendor': 'Edit',
          'name': 'generate_sbom.dart',
          'version': '1.0.0',
        }
      ],
    },
    'components': packages,
  };

  final outDir = Directory('${root.path}/release');
  outDir.createSync(recursive: true);
  final safeVer = appVersion.replaceAll('+', '_');
  final outPath = '${outDir.path}/sbom-$safeVer-$stamp.cdx.json';
  File(outPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(bom),
  );

  final manifest = {
    'product': 'Edit',
    'version': appVersion,
    'generatedAt': now.toIso8601String(),
    'componentCount': packages.length,
    'sbom': outPath.split('/').last,
    'note':
        'Archiviare insieme a hash binario e checklist. Non pubblicare per forza.',
  };
  File('${outDir.path}/release-manifest-$safeVer-$stamp.json')
      .writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );

  stdout.writeln('SBOM: $outPath (${packages.length} componenti)');
}
