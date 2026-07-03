import 'package:brainframe/engram/ui/file_tree_node.dart';
import 'package:flutter_test/flutter_test.dart';

/// A compact textual dump of the tree so structure/order is easy to assert.
/// Folders render as `name/` with indented children; files as `name`.
List<String> _dump(List<FileTreeNode> nodes, [int depth = 0]) {
  final lines = <String>[];
  for (final node in nodes) {
    lines.add('${'  ' * depth}${node.name}${node.isFolder ? '/' : ''}');
    if (node.isFolder) lines.addAll(_dump(node.children, depth + 1));
  }
  return lines;
}

void main() {
  test('empty input yields an empty tree', () {
    expect(buildFileTree(const []), isEmpty);
  });

  test('root-level files become leaves with their path', () {
    final tree = buildFileTree(['welcome.md', 'index.md']);
    expect(tree.every((n) => !n.isFolder), isTrue);
    final welcome = tree.firstWhere((n) => n.name == 'welcome.md');
    expect(welcome.path, 'welcome.md');
    expect(welcome.children, isEmpty);
  });

  test('nested paths fold into folders holding files', () {
    final tree = buildFileTree(['notes/first.md', 'notes/second.md']);
    expect(tree, hasLength(1));
    final notes = tree.single;
    expect(notes.isFolder, isTrue);
    expect(notes.name, 'notes');
    expect(notes.path, isNull);
    expect(notes.children.map((n) => n.name), ['first.md', 'second.md']);
    expect(notes.children.first.path, 'notes/first.md');
  });

  test('deeper nesting recurses', () {
    final tree = buildFileTree(['a/b/c.md']);
    expect(_dump(tree), ['a/', '  b/', '    c.md']);
    expect(tree.single.children.single.children.single.path, 'a/b/c.md');
  });

  test('folders sort before files, each alphabetically', () {
    final tree = buildFileTree([
      'zebra.md',
      'books/x.md',
      'apple.md',
      'articles/y.md',
    ]);
    expect(_dump(tree), [
      'articles/',
      '  y.md',
      'books/',
      '  x.md',
      'apple.md',
      'zebra.md',
    ]);
  });

  test('a folder gathered from several files appears once', () {
    final tree = buildFileTree([
      'books/a.md',
      'books/sub/b.md',
      'books/c.md',
    ]);
    final books = tree.single;
    expect(books.name, 'books');
    // One "sub" folder plus the two direct files, folder first.
    expect(_dump(books.children), ['sub/', '  b.md', 'a.md', 'c.md']);
  });

  test('duplicate paths collapse', () {
    final tree = buildFileTree(['welcome.md', 'welcome.md']);
    expect(tree, hasLength(1));
  });

  test('mixed case orders deterministically (case-insensitive, then raw)', () {
    final tree = buildFileTree(['B.md', 'a.md', 'A.md']);
    expect(tree.map((n) => n.name), ['A.md', 'a.md', 'B.md']);
  });

  group('isHiddenEngramPath', () {
    test('hides dotfiles and anything inside a dot-directory', () {
      expect(isHiddenEngramPath('.DS_Store'), isTrue);
      expect(isHiddenEngramPath('notes/.secret.md'), isTrue);
      expect(isHiddenEngramPath('.git/config'), isTrue);
      expect(isHiddenEngramPath('.brainframe/engram.json'), isTrue);
    });

    test('leaves ordinary files and folders visible', () {
      expect(isHiddenEngramPath('welcome.md'), isFalse);
      expect(isHiddenEngramPath('notes/first.md'), isFalse);
      // A dot mid-name (not leading) is not hidden.
      expect(isHiddenEngramPath('release.notes.md'), isFalse);
    });
  });
}
