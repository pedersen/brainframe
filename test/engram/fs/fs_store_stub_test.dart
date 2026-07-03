import 'package:brainframe/engram/fs/engram_location.dart';
import 'package:brainframe/engram/fs/fs_store_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const loc = EngramLocation('/anywhere');

  test('createFileSystemEngram is unsupported on the web stub', () {
    expect(
      () => createFileSystemEngram(location: loc, displayName: 'x'),
      throwsUnsupportedError,
    );
  });

  test('openFileSystemEngram is unsupported on the web stub', () {
    expect(() => openFileSystemEngram(loc), throwsUnsupportedError);
  });

  test('applicationEngramContainerPath is unsupported on the web stub', () {
    expect(() => applicationEngramContainerPath(), throwsUnsupportedError);
  });

  test('discoverContainerEngrams is unsupported on the web stub', () {
    expect(() => discoverContainerEngrams('/anywhere'), throwsUnsupportedError);
  });

  test('createContainerEngram is unsupported on the web stub', () {
    expect(
      () => createContainerEngram('/anywhere', 'x'),
      throwsUnsupportedError,
    );
  });
}
