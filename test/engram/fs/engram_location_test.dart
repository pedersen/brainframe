import 'package:brainframe/engram/fs/engram_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is a value type: equal paths compare equal', () {
    expect(const EngramLocation('/a'), const EngramLocation('/a'));
    expect(
      const EngramLocation('/a').hashCode,
      const EngramLocation('/a').hashCode,
    );
    expect(const EngramLocation('/a'), isNot(const EngramLocation('/b')));
  });

  test('toString exposes the path', () {
    expect(const EngramLocation('/a').toString(), 'EngramLocation(/a)');
  });
}
