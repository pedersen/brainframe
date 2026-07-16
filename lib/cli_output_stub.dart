/// Web / no-`dart:io` stub: the web build has no standard output and receives
/// no command-line arguments, so `--help` never reaches this and there is
/// nothing to print. Kept as an inert return (not a throw) so the seam stays
/// harmless if it is ever reached.
void printHelpAndExit(String message) {}
