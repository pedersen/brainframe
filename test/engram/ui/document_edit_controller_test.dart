import 'dart:convert';
import 'dart:typed_data';

import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/engram/ui/document_edit_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records each write as `path::text`, and can be told to fail the next one.
class _RecordingStore extends EngramStore {
  final List<String> writes = [];
  bool failNext = false;

  @override
  Future<List<String>> list() async => const [];

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    if (failNext) {
      failNext = false;
      throw Exception('write failed');
    }
    writes.add('$path::${utf8.decode(bytes)}');
  }
}

DocumentEditController _controller(_RecordingStore store) =>
    DocumentEditController(
      store: store,
      observeLifecycle: false,
      idleDebounce: const Duration(seconds: 5),
      maxWait: const Duration(seconds: 30),
    );

void main() {
  group('save pipeline', () {
    test('idle debounce writes once after the pause', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', 'hi');
        c.edit('hi there');
        expect(c.status, SaveStatus.dirty);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(store.writes, ['a.md::hi there']);
        expect(c.status, SaveStatus.saved);
        expect(c.isDirty, isFalse);
        c.dispose();
      });
    });

    test('the idle timer resets on each keystroke', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', '');
        c.edit('a');
        async.elapse(const Duration(seconds: 4)); // < 5s: no write yet
        c.edit('ab'); // resets the idle timer
        async.elapse(const Duration(seconds: 4)); // 8s total, but only 4s idle
        async.flushMicrotasks();
        expect(store.writes, isEmpty);

        async.elapse(const Duration(seconds: 1)); // now 5s idle since last edit
        async.flushMicrotasks();
        expect(store.writes, ['a.md::ab']);
        c.dispose();
      });
    });

    test('max-wait cap forces a write during continuous typing', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', '');
        // Type every 4s so the 5s idle timer never elapses; the 30s cap must
        // still checkpoint at least once.
        for (var i = 1; i <= 8; i++) {
          c.edit('x' * i);
          async.elapse(const Duration(seconds: 4));
        }
        async.flushMicrotasks();
        expect(store.writes, isNotEmpty);
        c.dispose();
      });
    });

    test('switching files flushes the outgoing file first', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', 'A');
        c.edit('A edited');
        c.openFile('b.md', 'B');
        async.flushMicrotasks();

        expect(store.writes, ['a.md::A edited']);
        expect(c.path, 'b.md');
        expect(c.text, 'B');
        expect(c.status, SaveStatus.saved);
        c.dispose();
      });
    });

    test('re-opening the current file keeps the live buffer', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', 'A');
        c.edit('A2');
        c.openFile('a.md', 'A'); // no-op; must not reset the buffer
        expect(c.text, 'A2');
        expect(c.isDirty, isTrue);
        c.dispose();
      });
    });

    test('app pause/hide/detach flushes the buffer', () {
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        fakeAsync((async) {
          final store = _RecordingStore();
          final c = _controller(store);
          c.openFile('a.md', 'A');
          c.edit('A2');
          c.didChangeAppLifecycleState(state);
          async.flushMicrotasks();
          expect(store.writes, ['a.md::A2'], reason: 'flushed on $state');
          c.dispose();
        });
      }
    });

    test('inactive/resumed lifecycle states do not write', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', 'A');
        c.edit('A2');
        c.didChangeAppLifecycleState(AppLifecycleState.inactive);
        c.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(store.writes, isEmpty);
        expect(c.isDirty, isTrue);
        c.dispose();
      });
    });

    test('a failed write sets error and keeps the buffer dirty', () {
      fakeAsync((async) {
        final store = _RecordingStore()..failNext = true;
        final c = _controller(store);
        c.openFile('a.md', 'A');
        c.edit('A2');
        c.flush();
        async.flushMicrotasks();
        expect(c.status, SaveStatus.error);
        expect(c.isDirty, isTrue);
        expect(store.writes, isEmpty);
        c.dispose();
      });
    });

    test('a pending debounce never writes to a switched-away file', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', 'A');
        c.edit('AA'); // idle timer armed for a.md
        c.openFile('b.md', 'B'); // flushes a.md, cancels the timer
        async.flushMicrotasks();
        final afterSwitch = store.writes.length;

        async.elapse(const Duration(seconds: 30)); // any stale timer would fire
        async.flushMicrotasks();

        expect(store.writes.length, afterSwitch);
        expect(store.writes, ['a.md::AA']);
        c.dispose();
      });
    });

    test('editing back to the saved text cancels the pending write', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', 'A');
        c.edit('A changed');
        expect(c.status, SaveStatus.dirty);
        c.edit('A'); // back to on-disk content
        expect(c.status, SaveStatus.saved);

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(store.writes, isEmpty);
        c.dispose();
      });
    });

    test('manual flush writes immediately', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', 'A');
        c.edit('A2');
        c.flush();
        async.flushMicrotasks();
        expect(store.writes, ['a.md::A2']);
        expect(c.status, SaveStatus.saved);
        c.dispose();
      });
    });

    test('flush is a no-op when clean', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        c.openFile('a.md', 'A');
        c.flush();
        async.flushMicrotasks();
        expect(store.writes, isEmpty);
        c.dispose();
      });
    });

    test('edit before any file is open is ignored', () {
      final store = _RecordingStore();
      final c = _controller(store);
      c.edit('x');
      expect(c.isDirty, isFalse);
      expect(c.status, SaveStatus.saved);
      c.dispose();
    });

    test('notifies listeners on status transitions', () {
      fakeAsync((async) {
        final store = _RecordingStore();
        final c = _controller(store);
        var notifications = 0;
        c.addListener(() => notifications++);
        c.openFile('a.md', 'A'); // stays saved: no transition
        c.edit('A2'); // saved -> dirty
        async.elapse(const Duration(seconds: 5)); // dirty -> saving -> saved
        async.flushMicrotasks();
        expect(notifications, greaterThanOrEqualTo(2));
        c.dispose();
      });
    });
  });

  group('lifecycle observer registration', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('registers on construct and unregisters on dispose', () {
      final store = _RecordingStore();
      // Default observeLifecycle: true exercises addObserver / removeObserver.
      final c = DocumentEditController(store: store);
      c.dispose();
    });
  });
}
