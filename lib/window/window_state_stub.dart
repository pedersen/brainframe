/// Web (and any non-`dart:io`) build: there is no desktop window to manage.
Future<void> initWindowManager() async {}

/// No-op where there is no OS window (see the io implementation).
void suspendWindowStatePersistence() {}
