/// Stable engram identifiers, encoded as ULIDs.
///
/// A ULID is a 128-bit, lexicographically sortable identifier: a 48-bit
/// millisecond timestamp followed by 80 bits of randomness, rendered as 26
/// Crockford base-32 characters. Encoding time first makes ids sort by
/// creation order; the random tail keeps them unique and unguessable. The id
/// survives folder renames and moves, so the registry and cross-references key
/// on it rather than the display name.
///
/// We roll this ~30-line helper rather than depend on the `ulid` package, to
/// keep the dependency surface small (see the Step 1 decision in
/// `docs/plans/engram-storage-impl.md`).
library;

import 'dart:math';

/// Crockford base-32 alphabet: the digits 0-9 and the uppercase letters with
/// I, L, O, and U removed, since those invite transcription errors.
const String crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Characters spent on the 48-bit millisecond timestamp (10 × 5 bits ≥ 48).
const int _timeChars = 10;

/// Characters spent on the 80 bits of randomness (16 × 5 bits = 80).
const int _randomChars = 16;

/// The length of a canonical ULID string.
const int ulidLength = _timeChars + _randomChars;

/// The largest millisecond timestamp a ULID can encode (2^48 - 1).
const int _maxUlidMillis = 0xFFFFFFFFFFFF;

final Random _secureRandom = Random.secure();

/// Generates a new ULID.
///
/// [timestamp] defaults to the current time and [random] to a secure
/// generator; both are injectable so tests can produce deterministic ids.
/// Throws [ArgumentError] if [timestamp] falls outside the 48-bit millisecond
/// range ULIDs can represent (before 1970 or after the year 10889).
String newUlid({DateTime? timestamp, Random? random}) {
  final millis = (timestamp ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  if (millis < 0 || millis > _maxUlidMillis) {
    throw ArgumentError.value(
      timestamp,
      'timestamp',
      'is outside the range a ULID can encode',
    );
  }
  final rng = random ?? _secureRandom;
  final chars = List<String>.filled(ulidLength, '0');
  var value = millis;
  for (var i = _timeChars - 1; i >= 0; i--) {
    chars[i] = crockfordAlphabet[value & 0x1f];
    value >>= 5;
  }
  for (var i = _timeChars; i < ulidLength; i++) {
    chars[i] = crockfordAlphabet[rng.nextInt(32)];
  }
  return chars.join();
}

/// Whether [value] is a canonical ULID: exactly [ulidLength] characters, all
/// drawn from the uppercase [crockfordAlphabet].
bool isCanonicalUlid(String value) {
  if (value.length != ulidLength) return false;
  for (var i = 0; i < value.length; i++) {
    if (!crockfordAlphabet.contains(value[i])) return false;
  }
  return true;
}
