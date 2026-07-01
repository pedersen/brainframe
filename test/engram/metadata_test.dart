import 'dart:convert';

import 'package:brainframe/engram/id.dart';
import 'package:brainframe/engram/metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sampleId = newUlid(timestamp: DateTime.utc(2026, 6, 29), random: null);

  EngramMetadata sample() => EngramMetadata(
        schemaVersion: EngramMetadata.currentSchemaVersion,
        id: sampleId,
        displayName: 'Personal',
        createdUtc: DateTime.utc(2026, 6, 29, 12),
      );

  group('EngramMetadata.create', () {
    test('stamps the current schema version and normalizes time to UTC', () {
      final local = DateTime(2026, 6, 29, 12); // local time
      final meta = EngramMetadata.create(
        id: sampleId,
        displayName: 'Personal',
        createdUtc: local,
      );
      expect(meta.schemaVersion, EngramMetadata.currentSchemaVersion);
      expect(meta.createdUtc.isUtc, isTrue);
      expect(meta.createdUtc, local.toUtc());
    });

    test('defaults createdUtc to now in UTC', () {
      final before = DateTime.now().toUtc();
      final meta = EngramMetadata.create(id: sampleId, displayName: 'X');
      final after = DateTime.now().toUtc();
      expect(meta.createdUtc.isUtc, isTrue);
      expect(
        meta.createdUtc.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        meta.createdUtc.isAfter(after.add(const Duration(seconds: 1))),
        isFalse,
      );
    });
  });

  group('round-trip', () {
    test('encode then decode reproduces the value', () {
      final meta = sample();
      expect(EngramMetadata.decode(meta.encode()), meta);
    });

    test('toJson then fromJson reproduces the value', () {
      final meta = sample();
      expect(EngramMetadata.fromJson(meta.toJson()), meta);
    });

    test('encode is pretty-printed and newline-terminated', () {
      final text = sample().encode();
      expect(text.endsWith('\n'), isTrue);
      expect(text.contains('\n  "id"'), isTrue); // two-space indent
      final asMap = jsonDecode(text) as Map<String, dynamic>;
      expect(asMap['schemaVersion'], 1);
      expect(asMap['displayName'], 'Personal');
      expect(asMap['createdUtc'], '2026-06-29T12:00:00.000Z');
    });
  });

  group('schema-version handling', () {
    test('rejects a missing schemaVersion', () {
      final json = sample().toJson()..remove('schemaVersion');
      expect(
        () => EngramMetadata.fromJson(json),
        throwsA(isA<EngramMetadataException>()),
      );
    });

    test('rejects a non-integer schemaVersion', () {
      final json = sample().toJson()..['schemaVersion'] = '1';
      expect(
        () => EngramMetadata.fromJson(json),
        throwsA(isA<EngramMetadataException>()),
      );
    });

    test('rejects a schemaVersion below 1', () {
      final json = sample().toJson()..['schemaVersion'] = 0;
      expect(
        () => EngramMetadata.fromJson(json),
        throwsA(isA<EngramMetadataException>()),
      );
    });

    test('rejects a future schemaVersion this build cannot read', () {
      final json = sample().toJson()
        ..['schemaVersion'] = EngramMetadata.currentSchemaVersion + 1;
      expect(
        () => EngramMetadata.fromJson(json),
        throwsA(
          isA<EngramMetadataException>().having(
            (e) => e.message,
            'message',
            contains('unsupported schemaVersion'),
          ),
        ),
      );
    });
  });

  group('field validation', () {
    test('rejects an id that is not a canonical ULID', () {
      final json = sample().toJson()..['id'] = 'not-a-ulid';
      expect(
        () => EngramMetadata.fromJson(json),
        throwsA(isA<EngramMetadataException>()),
      );
    });

    test('rejects a non-string id', () {
      final json = sample().toJson()..['id'] = 42;
      expect(
        () => EngramMetadata.fromJson(json),
        throwsA(isA<EngramMetadataException>()),
      );
    });

    test('rejects a missing or empty displayName', () {
      final missing = sample().toJson()..remove('displayName');
      final empty = sample().toJson()..['displayName'] = '';
      expect(
        () => EngramMetadata.fromJson(missing),
        throwsA(isA<EngramMetadataException>()),
      );
      expect(
        () => EngramMetadata.fromJson(empty),
        throwsA(isA<EngramMetadataException>()),
      );
    });

    test('rejects a non-string createdUtc', () {
      final json = sample().toJson()..['createdUtc'] = 0;
      expect(
        () => EngramMetadata.fromJson(json),
        throwsA(isA<EngramMetadataException>()),
      );
    });

    test('rejects an unparseable createdUtc', () {
      final json = sample().toJson()..['createdUtc'] = 'not-a-date';
      expect(
        () => EngramMetadata.fromJson(json),
        throwsA(isA<EngramMetadataException>()),
      );
    });
  });

  group('decode', () {
    test('rejects text that is not JSON', () {
      expect(
        () => EngramMetadata.decode('{not json'),
        throwsA(isA<EngramMetadataException>()),
      );
    });

    test('rejects JSON that is not an object', () {
      expect(
        () => EngramMetadata.decode('[1, 2, 3]'),
        throwsA(isA<EngramMetadataException>()),
      );
    });
  });

  group('value semantics', () {
    test('equal metadata are equal and share a hashCode', () {
      expect(sample(), sample());
      expect(sample().hashCode, sample().hashCode);
    });

    test('differing fields are unequal', () {
      final other = EngramMetadata(
        schemaVersion: sample().schemaVersion,
        id: sampleId,
        displayName: 'Different',
        createdUtc: sample().createdUtc,
      );
      expect(sample(), isNot(other));
    });

    test('toString and exception toString include useful context', () {
      expect(sample().toString(), contains('Personal'));
      expect(
        const EngramMetadataException('boom').toString(),
        'EngramMetadataException: boom',
      );
    });
  });
}
