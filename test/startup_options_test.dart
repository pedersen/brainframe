import 'package:brainframe/startup_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartupOptions.parse', () {
    test('an empty argument list yields defaults', () {
      final options = StartupOptions.parse(const []);
      expect(options.engramPath, isNull);
      expect(options.ignoreConfig, isFalse);
      expect(options.showHelp, isFalse);
    });

    test('--help and -h both request help', () {
      expect(StartupOptions.parse(['--help']).showHelp, isTrue);
      expect(StartupOptions.parse(['-h']).showHelp, isTrue);
    });

    test('help is recognized alongside other options', () {
      final options =
          StartupOptions.parse(['--engram=/z', '--ignore-config', '--help']);
      expect(options.showHelp, isTrue);
      expect(options.engramPath, '/z');
      expect(options.ignoreConfig, isTrue);
    });

    test('the usage text names every option', () {
      expect(StartupOptions.usage, contains('--engram'));
      expect(StartupOptions.usage, contains('--ignore-config'));
      expect(StartupOptions.usage, contains('--help'));
    });

    test('--engram with a space-separated path', () {
      final options = StartupOptions.parse(['--engram', '/notes/zettel']);
      expect(options.engramPath, '/notes/zettel');
      expect(options.ignoreConfig, isFalse);
    });

    test('--engram=<path> with an equals sign', () {
      final options = StartupOptions.parse(['--engram=/notes/zettel']);
      expect(options.engramPath, '/notes/zettel');
    });

    test('a path may itself contain spaces (space-separated form)', () {
      final options =
          StartupOptions.parse(['--engram', '/notes/book notes/Atomic']);
      expect(options.engramPath, '/notes/book notes/Atomic');
    });

    test('--ignore-config sets the flag', () {
      final options = StartupOptions.parse(['--ignore-config']);
      expect(options.ignoreConfig, isTrue);
      expect(options.engramPath, isNull);
    });

    test('both options together, in any order', () {
      final options =
          StartupOptions.parse(['--ignore-config', '--engram=/z']);
      expect(options.engramPath, '/z');
      expect(options.ignoreConfig, isTrue);
    });

    test('--engram with no following value is ignored (stays null)', () {
      final options = StartupOptions.parse(['--engram']);
      expect(options.engramPath, isNull);
    });

    test('an empty --engram= value is treated as absent', () {
      final options = StartupOptions.parse(['--engram=']);
      expect(options.engramPath, isNull);
    });

    test('bare positional arguments are ignored, valid options still apply', () {
      final options =
          StartupOptions.parse(['--engram=/z', 'stray', 'positional']);
      expect(options.engramPath, '/z');
      expect(options.ignoreConfig, isFalse);
    });

    test('an unknown option never throws — it falls back to defaults', () {
      // Launch-anyway behavior: an unrecognized flag can't stop the app, so the
      // whole parse degrades to safe defaults rather than aborting.
      final options = StartupOptions.parse(['--verbose']);
      expect(options.engramPath, isNull);
      expect(options.ignoreConfig, isFalse);
      expect(options.showHelp, isFalse);
    });

    test('an unknown option alongside valid ones still falls back to defaults',
        () {
      // Consequence of using a strict parser with a catch-all: a stray option
      // resets the batch. Correct invocations are unaffected.
      final options = StartupOptions.parse(['--engram=/z', '--nope']);
      expect(options.engramPath, isNull);
    });

    test('a later --engram wins over an earlier one', () {
      final options =
          StartupOptions.parse(['--engram=/first', '--engram', '/second']);
      expect(options.engramPath, '/second');
    });
  });
}
