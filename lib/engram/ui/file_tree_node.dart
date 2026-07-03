/// A node in the shallow folder tree the file browser renders.
///
/// An [EngramStore] lists content as flat, forward-slashed engram-relative
/// paths (`welcome.md`, `notes/first-note.md`); [buildFileTree] folds those
/// into a tree of folders and files so the sidebar can show disclosure
/// triangles. A node is either a **folder** (null [path], holding [children])
/// or a **file** leaf (non-null [path], empty [children]).
class FileTreeNode {
  /// A folder node: a display [name] and its (already-sorted) [children].
  const FileTreeNode.folder(this.name, this.children) : path = null;

  /// A file leaf: a display [name] and the engram-relative [path] to read.
  const FileTreeNode.file(this.name, String this.path) : children = const [];

  /// The last path segment — the folder or file name shown in the tree.
  final String name;

  /// The full engram-relative path for a file, or null for a folder.
  final String? path;

  /// Child nodes for a folder; always empty for a file.
  final List<FileTreeNode> children;

  /// Whether this node is a folder (as opposed to a file leaf).
  bool get isFolder => path == null;
}

/// Folds flat engram-relative [paths] into a sorted shallow folder tree.
///
/// Paths are split on `/`; each leading segment becomes a folder and the final
/// segment a file. Within every level, folders come first, then files, each
/// group sorted case-insensitively then by raw string for stability. Duplicate
/// paths collapse. Empty input yields an empty list.
List<FileTreeNode> buildFileTree(Iterable<String> paths) => _buildLevel(
      [for (final path in paths.toSet()) path.split('/')],
      '',
    );

/// Whether [path] should be hidden from the file browser: true when any of its
/// segments begins with a dot — a dotfile (`.DS_Store`), or anything inside a
/// dot-directory (`.git/config`, the app's own `.brainframe/…`). Matches the
/// usual hidden-file convention.
bool isHiddenEngramPath(String path) =>
    path.split('/').any((segment) => segment.startsWith('.'));

List<FileTreeNode> _buildLevel(List<List<String>> segmentLists, String prefix) {
  final folderSegments = <String, List<List<String>>>{};
  final fileNames = <String>{};

  for (final segments in segmentLists) {
    if (segments.length == 1) {
      fileNames.add(segments.first);
    } else {
      folderSegments
          .putIfAbsent(segments.first, () => <List<String>>[])
          .add(segments.sublist(1));
    }
  }

  final nodes = <FileTreeNode>[];
  for (final name in folderSegments.keys.toList()..sort(_byName)) {
    final childPrefix = prefix.isEmpty ? name : '$prefix/$name';
    nodes.add(
      FileTreeNode.folder(name, _buildLevel(folderSegments[name]!, childPrefix)),
    );
  }
  for (final name in fileNames.toList()..sort(_byName)) {
    nodes.add(FileTreeNode.file(name, prefix.isEmpty ? name : '$prefix/$name'));
  }
  return nodes;
}

/// Case-insensitive first, then raw, so `A.md`/`a.md` order deterministically.
int _byName(String a, String b) {
  final lower = a.toLowerCase().compareTo(b.toLowerCase());
  return lower != 0 ? lower : a.compareTo(b);
}
