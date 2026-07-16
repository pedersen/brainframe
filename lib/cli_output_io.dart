import 'dart:io';

/// Prints [message] to standard output and terminates the process successfully.
///
/// Used for `--help`, which must emit its text and exit before any window is
/// created. Declared `void` (not `Never`) to match the web stub's signature, so
/// the shared seam presents one API and callers need no platform branch; the
/// `exit(0)` still ends the process, so nothing after the call runs.
void printHelpAndExit(String message) {
  stdout.writeln(message);
  exit(0);
}
