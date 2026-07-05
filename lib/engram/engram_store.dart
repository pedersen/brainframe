import 'dart:convert';
import 'dart:typed_data';

/// The content-access contract for every engram.
///
/// Backends implement the read primitives — [list], [readBytes] — and
/// [writeBytes] over engram-relative paths, and never expose a `Directory`, so
/// the asset-backed built-in engrams (which have no directory) and any future
/// backend sit alongside on-disk engrams. Read-only stores (the asset bundle)
/// throw [UnsupportedError] from [writeBytes]; read-write stores (the
/// filesystem) implement it.
///
/// The remaining mutations — [delete], [move], [createDirectory],
/// [deleteDirectory] — default to a read-only store that throws
/// [UnsupportedError], so a partial or read-only backend need not restate them;
/// read-write stores override them. Whether an engram is read-only is carried
/// by `Engram.readOnly`, not asked of the store.
///
/// **Directories are first-class for enumeration.** [list] returns files;
/// [listDirectories] returns directory paths — including *empty* ones, which no
/// file path would reveal — so a browser can show a folder the user made but
/// has not filled yet, and folder operations can recreate and clean up shells.
/// It defaults to none, for backends (the asset bundle) that have no standalone
/// directory concept.
///
/// **Bytes are the primitive.** Engrams hold binary content — images, PDFs,
/// EPUBs — as first-class citizens alongside markdown, so the store speaks in
/// bytes and offers [readString]/[writeString] as UTF-8 conveniences on top.
/// Each backend implements only the byte methods and inherits the text ones,
/// which keeps text callers simple without every backend reimplementing the
/// encoding. (Streaming / random-access reads for very large documents are a
/// deliberately separate, later concern — they layer on additively and are not
/// needed to make the seam byte-capable.)
abstract class EngramStore {
  /// Lists every content file as an engram-relative path, e.g. `notes/a.md`.
  ///
  /// Paths use forward slashes on every platform and never begin with a
  /// leading slash. Order is unspecified.
  Future<List<String>> list();

  /// Lists every directory as an engram-relative path, e.g. `notes` or
  /// `notes/archive`, including empty directories that hold no files.
  ///
  /// Same path shape as [list] — forward slashes, no leading slash, order
  /// unspecified — and never includes the app-owned marker tree. Defaults to
  /// none for backends with no standalone directory concept; read-write stores
  /// override it so "new empty folder" and folder cleanup are representable.
  Future<List<String>> listDirectories() async => const [];

  /// Reads the raw bytes of the file at engram-relative [path].
  Future<Uint8List> readBytes(String path);

  /// Writes [bytes] to the file at engram-relative [path], creating or
  /// overwriting it.
  ///
  /// Read-only stores throw [UnsupportedError]; callers gate on
  /// `Engram.readOnly` rather than catching it.
  Future<void> writeBytes(String path, Uint8List bytes);

  /// Deletes the file at engram-relative [path].
  ///
  /// Deleting a path that is not an existing file is an error, surfaced by the
  /// backend. Defaults to a read-only store that throws [UnsupportedError];
  /// read-write stores override it, and callers gate on `Engram.readOnly`
  /// rather than catching.
  Future<void> delete(String path) => throw UnsupportedError(
        'This store is read-only; cannot delete "$path".',
      );

  /// Moves (or renames) the file at [from] to [to], both engram-relative.
  ///
  /// The destination's parent directories are created as needed; the
  /// destination must not already exist. Defaults to a read-only store that
  /// throws [UnsupportedError]; read-write stores override it.
  Future<void> move(String from, String to) => throw UnsupportedError(
        'This store is read-only; cannot move "$from".',
      );

  /// Creates an empty directory at engram-relative [path], including any
  /// missing parents; a no-op if it already exists.
  ///
  /// Directories are otherwise implicit — [writeBytes] creates a file's
  /// parents — so this exists for "new empty folder" and the destination shell
  /// of a folder move. Defaults to a read-only store that throws
  /// [UnsupportedError]; read-write stores override it.
  Future<void> createDirectory(String path) => throw UnsupportedError(
        'This store is read-only; cannot create directory "$path".',
      );

  /// Removes the directory at engram-relative [path], which must be empty.
  ///
  /// The removal counterpart to [createDirectory]. Folder composition (see
  /// `EngramFileOps`) deletes descendant files first, then removes the emptied
  /// directory shells deepest-first. Removing a missing or non-empty directory
  /// is an error, surfaced by the backend. Defaults to a read-only store that
  /// throws [UnsupportedError]; read-write stores override it.
  Future<void> deleteDirectory(String path) => throw UnsupportedError(
        'This store is read-only; cannot delete directory "$path".',
      );

  /// Reads the file at engram-relative [path] as UTF-8 text.
  ///
  /// A convenience over [readBytes]; do not use it for binary content.
  Future<String> readString(String path) async =>
      utf8.decode(await readBytes(path));

  /// Writes [contents] as UTF-8 to the file at engram-relative [path].
  ///
  /// A convenience over [writeBytes]; throws from read-only stores just as
  /// [writeBytes] does.
  Future<void> writeString(String path, String contents) =>
      writeBytes(path, Uint8List.fromList(utf8.encode(contents)));

  /// Releases any resources this store holds — an open location handle, a file
  /// watcher — when its engram is switched away from or the app tears down.
  ///
  /// A no-op for v1's stateless stores (the asset bundle, a plain filesystem
  /// path); the seam exists so a future security-scoped filesystem handle
  /// (Location B, v2) can be freed before the next engram's store is used, per
  /// Decision 2. `EngramScope` calls this on the outgoing engram; releasing a
  /// store twice, or using it after release, is a backend's own concern.
  Future<void> release() async {}
}
