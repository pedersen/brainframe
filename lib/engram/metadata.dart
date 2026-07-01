/// The parsed contents of an engram's `.brainframe/engram.json`.
///
/// This is the on-disk identity of a filesystem engram: a schema version, the
/// stable [id], a [displayName], and a creation timestamp. Parsing is strict —
/// a malformed or future-versioned file raises [EngramMetadataException]
/// rather than silently producing a half-valid engram.
library;

import 'dart:convert';

import 'id.dart';

/// Thrown when `engram.json` cannot be parsed into a valid [EngramMetadata].
class EngramMetadataException implements Exception {
  const EngramMetadataException(this.message);

  final String message;

  @override
  String toString() => 'EngramMetadataException: $message';
}

/// Metadata for a single engram, serialized to and from `engram.json`.
class EngramMetadata {
  const EngramMetadata({
    required this.schemaVersion,
    required this.id,
    required this.displayName,
    required this.createdUtc,
  });

  /// Builds metadata for a freshly created engram, stamping the current schema
  /// version and normalizing [createdUtc] (defaulting to now) to UTC.
  factory EngramMetadata.create({
    required String id,
    required String displayName,
    DateTime? createdUtc,
  }) =>
      EngramMetadata(
        schemaVersion: currentSchemaVersion,
        id: id,
        displayName: displayName,
        createdUtc: (createdUtc ?? DateTime.now()).toUtc(),
      );

  /// Parses [source], the raw text of an `engram.json` file.
  ///
  /// Throws [EngramMetadataException] if the text is not a JSON object or any
  /// field is missing, mistyped, or unsupported.
  factory EngramMetadata.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw EngramMetadataException('engram.json is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const EngramMetadataException('engram.json must be a JSON object');
    }
    return EngramMetadata.fromJson(decoded);
  }

  /// Builds metadata from an already-decoded JSON [json] map, validating every
  /// field. Throws [EngramMetadataException] on any problem.
  factory EngramMetadata.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int) {
      throw const EngramMetadataException(
        'schemaVersion is required and must be an integer',
      );
    }
    if (version < 1 || version > currentSchemaVersion) {
      throw EngramMetadataException(
        'unsupported schemaVersion $version '
        '(this build understands 1..$currentSchemaVersion)',
      );
    }

    final id = json['id'];
    if (id is! String || !isCanonicalUlid(id)) {
      throw const EngramMetadataException('id must be a canonical ULID string');
    }

    final displayName = json['displayName'];
    if (displayName is! String || displayName.isEmpty) {
      throw const EngramMetadataException(
        'displayName is required and must be a non-empty string',
      );
    }

    final createdRaw = json['createdUtc'];
    if (createdRaw is! String) {
      throw const EngramMetadataException(
        'createdUtc is required and must be an ISO-8601 string',
      );
    }
    final DateTime createdUtc;
    try {
      createdUtc = DateTime.parse(createdRaw).toUtc();
    } on FormatException {
      throw EngramMetadataException(
        'createdUtc is not a valid ISO-8601 timestamp: $createdRaw',
      );
    }

    return EngramMetadata(
      schemaVersion: version,
      id: id,
      displayName: displayName,
      createdUtc: createdUtc,
    );
  }

  /// The schema version this build writes and is the newest it can read.
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String displayName;
  final DateTime createdUtc;

  /// The JSON object form, with [createdUtc] rendered as a UTC ISO-8601 string.
  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'displayName': displayName,
        'createdUtc': createdUtc.toUtc().toIso8601String(),
      };

  /// Serializes to the pretty-printed, newline-terminated text written to
  /// `engram.json`. `decode(encode())` round-trips.
  String encode() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  @override
  bool operator ==(Object other) =>
      other is EngramMetadata &&
      other.schemaVersion == schemaVersion &&
      other.id == id &&
      other.displayName == displayName &&
      other.createdUtc == createdUtc;

  @override
  int get hashCode => Object.hash(schemaVersion, id, displayName, createdUtc);

  @override
  String toString() =>
      'EngramMetadata(schemaVersion: $schemaVersion, id: $id, '
      'displayName: $displayName, createdUtc: ${createdUtc.toIso8601String()})';
}
