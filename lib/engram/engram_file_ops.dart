import 'engram_store.dart';

/// Folder-level operations composed over an [EngramStore]'s file and directory
/// primitives.
///
/// Folder rename/move/delete are deliberately *not* store methods: keeping the
/// store contract at the file level keeps every backend (asset, filesystem,
/// future) small, and keeps folder semantics in one tested place (design:
/// "Folders compose over file primitives").
///
/// A folder is addressed by its engram-relative path — forward slashes, no
/// leading or trailing slash, e.g. `notes` or `notes/archive`. Operations that
/// take a destination require it to be free; callers pick a non-colliding name
/// with [freeName].
class EngramFileOps {
  EngramFileOps(this.store);

  final EngramStore store;

  /// Moves the folder at [from] to [to], carrying every descendant file and
  /// preserving empty subfolders, then removing the emptied source shells.
  ///
  /// The destination tree is created first — so empty subfolders survive the
  /// move even though no file would recreate them — then each descendant file
  /// is moved into the mirrored path, then the source directories are removed
  /// deepest-first. [to] must not already exist.
  Future<void> moveFolder(String from, String to) async {
    final fromPrefix = _prefix(from);
    final descendantDirs = [
      for (final d in await store.listDirectories())
        if (d == from || d.startsWith(fromPrefix)) d,
    ];

    // Recreate the destination shell and every subfolder, including empties.
    await store.createDirectory(to);
    for (final dir in descendantDirs) {
      if (dir == from) continue;
      await store.createDirectory('$to${dir.substring(from.length)}');
    }

    // Move each descendant file into the mirrored destination path.
    for (final file in await store.list()) {
      if (file.startsWith(fromPrefix)) {
        await store.move(file, '$to${file.substring(from.length)}');
      }
    }

    // Remove the emptied source tree, deepest first (so each is empty in turn).
    for (final dir in _deepestFirst(descendantDirs)) {
      await store.deleteDirectory(dir);
    }
  }

  /// Renames the folder at [path] to [newName] within the same parent.
  ///
  /// A thin wrapper over [moveFolder]; [newName] is a single path segment and
  /// must be free among the folder's siblings.
  Future<void> renameFolder(String path, String newName) {
    final slash = path.lastIndexOf('/');
    final parent = slash == -1 ? '' : path.substring(0, slash + 1);
    return moveFolder(path, '$parent$newName');
  }

  /// Deletes the folder at [path] and everything beneath it: every descendant
  /// file, then the emptied directory shells deepest-first (including [path]).
  Future<void> deleteFolder(String path) async {
    final prefix = _prefix(path);
    for (final file in await store.list()) {
      if (file.startsWith(prefix)) await store.delete(file);
    }
    final dirs = [
      for (final d in await store.listDirectories())
        if (d == path || d.startsWith(prefix)) d,
    ];
    for (final dir in _deepestFirst(dirs)) {
      await store.deleteDirectory(dir);
    }
  }

  /// Returns [desired] if no sibling name in [existing] uses it, otherwise the
  /// first free `"[desired] 2"`, `"[desired] 3"`, … — the same numbering the
  /// filesystem store uses for engram folders, so new notes, new folders, and
  /// move destinations never collide with a sibling.
  static String freeName(String desired, Set<String> existing) {
    if (!existing.contains(desired)) return desired;
    var suffix = 2;
    while (existing.contains('$desired $suffix')) {
      suffix++;
    }
    return '$desired $suffix';
  }

  static String _prefix(String folderPath) =>
      folderPath.endsWith('/') ? folderPath : '$folderPath/';

  /// Sorts [dirs] deepest-first (most path segments first), so removing them in
  /// order empties each parent before it is reached.
  static List<String> _deepestFirst(List<String> dirs) {
    final sorted = [...dirs];
    sorted.sort((a, b) {
      final byDepth = _depth(b).compareTo(_depth(a));
      return byDepth != 0 ? byDepth : b.compareTo(a);
    });
    return sorted;
  }

  static int _depth(String path) => '/'.allMatches(path).length;
}
