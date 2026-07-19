import 'package:brainframe/window/window_state_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stub initWindowManager is a no-op that completes', () async {
    // On web (and any non-dart:io build) there is no OS window to manage;
    // the stub simply returns. Calling it here covers that path.
    await expectLater(initWindowManager(), completes);
  });

  test('stub suspendWindowStatePersistence is a no-op', () {
    // No OS window to persist; the stub just returns.
    expect(suspendWindowStatePersistence, returnsNormally);
  });
}
