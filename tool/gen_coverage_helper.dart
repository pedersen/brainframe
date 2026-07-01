// Regenerates test/coverage/all_files_test.dart: an aggregate test that
// imports every lib/**.dart file so `flutter test --coverage` counts files no
// other test references. Without it, unreferenced libraries are simply absent
// from coverage/lcov.info and silently inflate the percentage; importing them
// here makes them show up at 0% instead of vanishing — the "honest" part of
// the coverage gate.
//
// The coverage pipeline (tool/coverage.sh) runs this before every measurement,
// so the generated file can never go stale as later steps add libraries. It is
// still committed so `flutter test` works without a regeneration step.
//
// Run manually with: dart run tool/gen_coverage_helper.dart
import 'dart:io';

void main() {
  final repoRoot = Directory.current;
  final libDir = Directory('${repoRoot.path}/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('gen_coverage_helper: no lib/ directory at ${libDir.path}');
    exit(1);
  }

  final libRoot = libDir.path;
  final imports = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .map((p) => p.substring(libRoot.length + 1)) // strip "lib/"
      .map((rel) => rel.replaceAll(Platform.pathSeparator, '/'))
      .toList()
    ..sort();

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('// Regenerate with: dart run tool/gen_coverage_helper.dart')
    ..writeln('//')
    ..writeln('// Imports every lib/ library so `flutter test --coverage`')
    ..writeln('// reports untested files as 0% instead of omitting them.')
    ..writeln('// ignore_for_file: unused_import')
    ..writeln();
  for (final rel in imports) {
    buffer.writeln("import 'package:brainframe/$rel';");
  }
  buffer
    ..writeln()
    ..writeln('void main() {}');

  final outFile = File('${repoRoot.path}/test/coverage/all_files_test.dart');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(buffer.toString());
  stdout.writeln(
    'gen_coverage_helper: wrote ${imports.length} imports to ${outFile.path}',
  );
}
