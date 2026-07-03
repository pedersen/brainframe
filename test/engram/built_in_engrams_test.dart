import 'package:brainframe/engram/built_in_engrams.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('surfaces exactly the tutorial and help engrams, read-only', () {
    final engrams = builtInEngrams();
    expect(engrams.map((e) => e.id), [builtinTutorialId, builtinHelpId]);
    expect(engrams.map((e) => e.displayName), ['Tutorial', 'Help']);
    expect(engrams.every((e) => e.readOnly), isTrue);
  });

  test('built-in stores read their bundled content', () async {
    final tutorial =
        builtInEngrams().firstWhere((e) => e.id == builtinTutorialId);
    expect(
      await tutorial.store.readString('welcome.md'),
      contains('Welcome to BrainFrame'),
    );
  });

  test('isBuiltInEngramId recognizes the built-ins and nothing else', () {
    expect(isBuiltInEngramId(builtinTutorialId), isTrue);
    expect(isBuiltInEngramId(builtinHelpId), isTrue);
    expect(isBuiltInEngramId('01JZZ0000000000000000000ZZ'), isFalse);
  });
}
