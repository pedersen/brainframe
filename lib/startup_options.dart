/// Startup options parsed from the process command line.
///
/// Desktop only in practice — Flutter forwards `argv` to `main` on desktop,
/// while mobile and web always start `main` with an empty list — but parsing is
/// pure string work with no `dart:io`, so it is unit-testable and safe to run on
/// every platform (an empty list yields the default behavior).
///
/// Both options exist for development and testing. See [engramPath] and
/// [ignoreConfig].
class StartupOptions {
  const StartupOptions({
    this.engramPath,
    this.ignoreConfig = false,
    this.showHelp = false,
  });

  /// Human-readable usage text for `--help`. Printed to the terminal before
  /// Flutter starts, so it is plain output rather than a localized UI string.
  static const String usage = '''
BrainFrame — an open-source Second Brain / E-Reader.

Usage: brainframe [options]

Options:
  --engram <path>   Open the engram at <path> at startup instead of the
                    last-opened one. If <path> is a plain folder it is turned
                    into an engram in place. Transient: not remembered next run.
  --ignore-config   Start without reading or writing saved configuration — the
                    engram registry, last-opened engram, window geometry, and
                    theme. Handy for a clean-slate testing session.
  --help, -h        Print this message and exit.

These options apply to desktop builds; mobile and web ignore them.''';

  /// An explicit engram folder to open at startup (`--engram <path>` or
  /// `--engram=<path>`), bypassing the normally remembered last-opened engram.
  /// Null when the flag is absent or empty.
  ///
  /// The override is transient: it is not added to the registry or recorded as
  /// the last-opened engram, so a later ordinary launch resolves as usual.
  final String? engramPath;

  /// Start without reading or writing the saved configuration
  /// (`--ignore-config`). When set, the app backs its preferences with an
  /// ephemeral in-memory store, so the real engram registry, last-opened
  /// engram, window geometry, and theme are neither loaded nor overwritten.
  final bool ignoreConfig;

  /// Print [usage] and exit without starting the app (`--help` or `-h`). When
  /// set it takes precedence over every other option.
  final bool showHelp;

  /// Parses [args], recognizing `--engram <path>` / `--engram=<path>`,
  /// `--ignore-config`, and `--help` / `-h`. Unknown arguments are ignored
  /// rather than rejected, so a stray flag (or a Flutter-injected one) never
  /// stops the app from launching.
  factory StartupOptions.parse(List<String> args) {
    String? engramPath;
    var ignoreConfig = false;
    var showHelp = false;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
      } else if (arg == '--ignore-config') {
        ignoreConfig = true;
      } else if (arg == '--engram') {
        // Space-separated form: the next argument is the path, if present.
        if (i + 1 < args.length) engramPath = args[++i];
      } else if (arg.startsWith('--engram=')) {
        engramPath = arg.substring('--engram='.length);
      }
    }
    return StartupOptions(
      engramPath:
          (engramPath != null && engramPath.isNotEmpty) ? engramPath : null,
      ignoreConfig: ignoreConfig,
      showHelp: showHelp,
    );
  }
}
