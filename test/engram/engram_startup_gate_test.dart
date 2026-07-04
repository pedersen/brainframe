import 'dart:async';
import 'dart:typed_data';

import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_scope.dart';
import 'package:brainframe/engram/engram_startup_gate.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

class _EmptyStore extends EngramStore {
  @override
  Future<List<String>> list() async => const [];
  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);
  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {}
}

Engram _engram(String id) =>
    Engram(id: id, displayName: id, readOnly: false, store: _EmptyStore());

Widget _gate({
  required Future<Engram> Function() resolve,
  Future<void> Function(Engram)? onSwitched,
  Widget child = const SizedBox.shrink(),
}) =>
    localizedApp(
      home: EngramStartupGate(
        resolveInitialEngram: resolve,
        onSwitched: onSwitched,
        child: child,
      ),
    );

void main() {
  testWidgets('shows a progress indicator while the engram resolves',
      (tester) async {
    final pending = Completer<Engram>();
    await tester.pumpWidget(_gate(resolve: () => pending.future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Opening BrainFrame'), findsOneWidget);

    // Let the pending future complete so the test ends cleanly.
    pending.complete(_engram('tutorial'));
    await tester.pumpAndSettle();
  });

  testWidgets('installs an EngramScope with the resolved engram', (tester) async {
    String? active;
    await tester.pumpWidget(
      _gate(
        resolve: () async => _engram('tutorial'),
        child: Builder(builder: (context) {
          active = EngramScope.of(context).engram.id;
          return const SizedBox.shrink();
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(active, 'tutorial');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('surfaces a message when resolution fails', (tester) async {
    await tester.pumpWidget(
      _gate(resolve: () async => throw StateError('boom')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not open your engrams.'), findsOneWidget);
  });

  testWidgets('runs startup resolution only once across rebuilds',
      (tester) async {
    var calls = 0;
    Future<Engram> resolve() async {
      calls++;
      return _engram('tutorial');
    }

    await tester.pumpWidget(_gate(resolve: resolve));
    await tester.pumpAndSettle();
    // Force the gate to rebuild; startup must not re-run.
    await tester.pumpWidget(_gate(resolve: resolve));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
