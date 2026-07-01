/// The content-access contract for every engram.
///
/// Callers use engram-relative paths and never see a `Directory`, so the
/// asset-backed built-in engrams (which have no directory) and any future
/// backend sit alongside on-disk engrams. Read-only stores (the asset bundle)
/// throw from [writeString]; read-write stores (the filesystem) implement it.
/// Whether an engram is read-only is carried by `Engram.readOnly`, not asked
/// of the store.
abstract class EngramStore {
  /// Lists every content file as an engram-relative path, e.g. `notes/a.md`.
  ///
  /// Paths use forward slashes on every platform and never begin with a
  /// leading slash. Order is unspecified.
  Future<List<String>> list();

  /// Reads the UTF-8 text of the file at engram-relative [path].
  Future<String> readString(String path);

  /// Writes [contents] as UTF-8 to the file at engram-relative [path],
  /// creating or overwriting it.
  ///
  /// Read-only stores throw [UnsupportedError]; callers gate on
  /// `Engram.readOnly` rather than catching it.
  Future<void> writeString(String path, String contents);
}
