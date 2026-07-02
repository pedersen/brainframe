import 'dart:convert';
import 'dart:typed_data';

/// The content-access contract for every engram.
///
/// Backends implement three primitives — [list], [readBytes], [writeBytes] —
/// over engram-relative paths, and never expose a `Directory`, so the
/// asset-backed built-in engrams (which have no directory) and any future
/// backend sit alongside on-disk engrams. Read-only stores (the asset bundle)
/// throw [UnsupportedError] from [writeBytes]; read-write stores (the
/// filesystem) implement it. Whether an engram is read-only is carried by
/// `Engram.readOnly`, not asked of the store.
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

  /// Reads the raw bytes of the file at engram-relative [path].
  Future<Uint8List> readBytes(String path);

  /// Writes [bytes] to the file at engram-relative [path], creating or
  /// overwriting it.
  ///
  /// Read-only stores throw [UnsupportedError]; callers gate on
  /// `Engram.readOnly` rather than catching it.
  Future<void> writeBytes(String path, Uint8List bytes);

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
}
