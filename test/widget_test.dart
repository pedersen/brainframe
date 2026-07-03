import 'package:brainframe/app.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  // No filesystem container in a plain widget test: the resolver throws, so
  // discovery degrades to the built-ins and startup opens the tutorial.
  BrainFrameApp app() => BrainFrameApp(
        repository: EngramRepository(
          preferences: SharedPreferencesAsync(),
          containerPathResolver: () async =>
              throw UnsupportedError('no filesystem in widget tests'),
        ),
      );

  testWidgets('App builds and shows the home screen', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle(); // resolve the startup engram, then render home

    // Title (in the app bar/nav bar) and the headline both read "BrainFrame".
    expect(find.text('BrainFrame'), findsWidgets);
    expect(find.text('Your second brain and e-reader.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Get started opens the welcome dialog', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('BrainFrame is up and running.'), findsOneWidget);
  });
}
