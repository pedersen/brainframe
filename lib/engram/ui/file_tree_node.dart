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

/// Folds flat engram-relative [filePaths] into a sorted shallow folder tree.
///
/// Paths are split on `/`; each leading segment becomes a folder and the final
/// segment a file. [directoryPaths] adds folders that hold no files yet — an
/// empty folder the user created — which no file path would otherwise reveal;
/// each is materialized as a folder node (with its ancestors). Within every
/// level, folders come first, then files, each group sorted case-insensitively
/// then by raw string for stability. Duplicate paths collapse. Empty input
/// yields an empty list.
List<FileTreeNode> buildFileTree(
  Iterable<String> filePaths, {
  Iterable<String> directoryPaths = const [],
}) {
  // Every folder in the tree: the ancestor of each file, plus each explicit
  // directory path and its ancestors.
  final folders = <String>{};
  void addAncestors(String path) {
    final segments = path.split('/');
    for (var i = 1; i < segments.length; i++) {
      folders.add(segments.sublist(0, i).join('/'));
    }
  }

  for (final file in filePaths) {
    addAncestors(file);
  }
  for (final directory in directoryPaths) {
    folders.add(directory);
    addAncestors(directory);
  }
  return _buildLevel('', folders, filePaths.toSet());
}

/// Whether [path] should be hidden from the file browser: true when any of its
/// segments begins with a dot — a dotfile (`.DS_Store`), or anything inside a
/// dot-directory (`.git/config`, the app's own `.brainframe/…`). Matches the
/// usual hidden-file convention.
bool isHiddenEngramPath(String path) =>
    path.split('/').any((segment) => segment.startsWith('.'));

List<FileTreeNode> _buildLevel(
  String prefix,
  Set<String> folders,
  Set<String> files,
) {
  final childPrefix = prefix.isEmpty ? '' : '$prefix/';
  bool isDirectChild(String path) =>
      path.startsWith(childPrefix) &&
      !path.substring(childPrefix.length).contains('/');

  final nodes = <FileTreeNode>[];
  final folderNames = [
    for (final folder in folders)
      if (isDirectChild(folder)) folder.substring(childPrefix.length),
  ]..sort(_byName);
  for (final name in folderNames) {
    final path = prefix.isEmpty ? name : '$prefix/$name';
    nodes.add(FileTreeNode.folder(name, _buildLevel(path, folders, files)));
  }

  final filePaths = [for (final file in files) if (isDirectChild(file)) file]
    ..sort((a, b) => _byName(a.split('/').last, b.split('/').last));
  for (final path in filePaths) {
    nodes.add(FileTreeNode.file(path.split('/').last, path));
  }
  return nodes;
}

/// Case-insensitive first, then raw, so `A.md`/`a.md` order deterministically.
int _byName(String a, String b) {
  final lower = a.toLowerCase().compareTo(b.toLowerCase());
  return lower != 0 ? lower : a.compareTo(b);
}
