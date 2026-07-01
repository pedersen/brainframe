import 'dart:math';

import 'package:brainframe/engram/id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('crockfordAlphabet', () {
    test('has 32 distinct characters and omits I, L, O, U', () {
      expect(crockfordAlphabet.length, 32);
      expect(crockfordAlphabet.split('').toSet().length, 32);
      for (final excluded in ['I', 'L', 'O', 'U']) {
        expect(crockfordAlphabet.contains(excluded), isFalse);
      }
    });
  });

  group('newUlid', () {
    test('produces a canonical 26-character id with default arguments', () {
      final id = newUlid();
      expect(id.length, ulidLength);
      expect(isCanonicalUlid(id), isTrue);
    });

    test('is deterministic for a fixed timestamp and seeded random', () {
      final ts = DateTime.utc(2026, 6, 29, 12);
      final a = newUlid(timestamp: ts, random: Random(42));
      final b = newUlid(timestamp: ts, random: Random(42));
      expect(a, b);
      expect(isCanonicalUlid(a), isTrue);
    });

    test('encodes time in the prefix so ids sort by creation order', () {
      final earlier = newUlid(
        timestamp: DateTime.utc(2026, 1, 1),
        random: Random(1),
      );
      final later = newUlid(
        timestamp: DateTime.utc(2026, 12, 31),
        random: Random(1),
      );
      // Same seed => identical random tail, so only the time prefix differs.
      expect(earlier.compareTo(later), lessThan(0));
      expect(earlier.substring(10), later.substring(10));
    });

    test('the random tail differs for the same timestamp', () {
      final ts = DateTime.utc(2026, 6, 29);
      final a = newUlid(timestamp: ts, random: Random(1));
      final b = newUlid(timestamp: ts, random: Random(2));
      expect(a.substring(0, 10), b.substring(0, 10)); // same time prefix
      expect(a, isNot(b)); // different randomness
    });

    test('throws for a timestamp before the Unix epoch', () {
      expect(
        () => newUlid(timestamp: DateTime.utc(1969)),
        throwsArgumentError,
      );
    });

    test('throws for a timestamp beyond the 48-bit range', () {
      expect(
        () => newUlid(timestamp: DateTime.utc(20000)),
        throwsArgumentError,
      );
    });
  });

  group('isCanonicalUlid', () {
    test('accepts a freshly generated id', () {
      expect(isCanonicalUlid(newUlid()), isTrue);
    });

    test('rejects the wrong length', () {
      expect(isCanonicalUlid(''), isFalse);
      expect(isCanonicalUlid('0' * (ulidLength - 1)), isFalse);
      expect(isCanonicalUlid('0' * (ulidLength + 1)), isFalse);
    });

    test('rejects characters outside the alphabet', () {
      expect(isCanonicalUlid('I' * ulidLength), isFalse); // excluded letter
      expect(isCanonicalUlid('a' * ulidLength), isFalse); // lowercase
    });
  });
}
