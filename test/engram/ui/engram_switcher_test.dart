import 'package:brainframe/engram/built_in_engrams.dart';
import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:brainframe/engram/engram_scope.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/engram/fs/fs_store.dart';
import 'package:brainframe/engram/ui/engram_switcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A no-op store for fake engrams — these tests exercise the switcher widget,
/// not content access.
class _FakeStore extends EngramStore {
  @override
  Future<List<String>> list() async => const [];
  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);
  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {}
}

Engram _engram(String id, String name, {bool readOnly = false}) =>
    Engram(id: id, displayName: name, readOnly: readOnly, store: _FakeStore());

/// A repository whose discovery/create are canned, so the switcher can be
/// driven under `testWidgets` without real filesystem I/O (which would hang the
/// fake-async test zone). Repository I/O correctness lives in
/// engram_repository_test.
class _FakeRepo extends EngramRepository {
  _FakeRepo({required this.discovery})
      : super(
          preferences: SharedPreferencesAsync(),
          containerPathResolver: () async => throw UnsupportedError('no fs'),
        );

  final EngramDiscovery discovery;

  @override
  Future<EngramDiscovery> discover() async => discovery;

  @override
  Future<Engram> create(String displayName) async =>
      _engram('created-$displayName', displayName);
}

void main() {
  final tutorial = _engram(builtinTutorialId, 'Tutorial', readOnly: true);
  final help = _engram(builtinHelpId, 'Help', readOnly: true);

  EngramDiscovery discovery({List<UnavailableEngram> unavailable = const []}) =>
      EngramDiscovery(available: [tutorial, help], unavailable: unavailable);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Widget harness(EngramRepository repository, Engram initial) => MaterialApp(
        home: EngramScope(
          initialEngram: initial,
          child: Scaffold(
            body: Builder(builder: (context) {
              final active = EngramScope.of(context).engram;
              return Column(
                children: [
                  Text('active:${active.id}'),
                  const Spacer(),
                  EngramSwitcher(repository: repository, current: active),
                ],
              );
            }),
          ),
        ),
      );

  testWidgets('footer shows the engram name and a read-only lock',
      (tester) async {
    await tester.pumpWidget(harness(_FakeRepo(discovery: discovery()), tutorial));
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('a writable engram has no lock', (tester) async {
    final mine = _engram('mine', 'Mine');
    await tester.pumpWidget(harness(_FakeRepo(discovery: discovery()), mine));
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('opening the sheet lists engrams; selecting one switches',
      (tester) async {
    await tester.pumpWidget(harness(_FakeRepo(discovery: discovery()), tutorial));

    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('New engram'), findsOneWidget);

    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(find.text('active:$builtinHelpId'), findsOneWidget);
  });

  testWidgets('New engram prompts for a name, creates, and switches',
      (tester) async {
    await tester.pumpWidget(harness(_FakeRepo(discovery: discovery()), tutorial));

    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New engram'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Journal');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('active:created-Journal'), findsOneWidget);
    expect(find.text('Journal'), findsWidgets); // footer renamed
  });

  testWidgets('an unavailable registry root is listed but disabled',
      (tester) async {
    final repo = _FakeRepo(
      discovery: discovery(unavailable: [
        const UnavailableEngram(
          id: 'gone',
          displayName: 'Archived',
          location: EngramLocation('/missing'),
        ),
      ]),
    );
    await tester.pumpWidget(harness(repo, tutorial));

    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();

    expect(find.text('Archived'), findsOneWidget);
    expect(find.textContaining('Unavailable'), findsOneWidget);
    // Tapping a disabled row does nothing — still on the tutorial.
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('active:$builtinTutorialId'), findsOneWidget);
  });

  testWidgets('Open folder… appears only on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(harness(_FakeRepo(discovery: discovery()), tutorial));
    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Open folder…'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20)); // dismiss the sheet
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(harness(_FakeRepo(discovery: discovery()), tutorial));
    await tester.tap(find.text('Tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Open folder…'), findsNothing);

    // Reset before the body ends: testWidgets checks foundation debug vars are
    // unset before group tearDown runs.
    debugDefaultTargetPlatformOverride = null;
  });
}
