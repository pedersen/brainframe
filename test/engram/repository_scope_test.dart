import 'package:brainframe/engram/engram_repository.dart';
import 'package:brainframe/engram/repository_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  EngramRepository repo() => EngramRepository(
        preferences: SharedPreferencesAsync(),
        containerPathResolver: () async => throw StateError('no container'),
      );

  Widget scoped(EngramRepository repository, void Function(EngramRepository) sink) =>
      RepositoryScope(
        repository: repository,
        child: Builder(
          builder: (context) {
            sink(RepositoryScope.of(context));
            return const SizedBox();
          },
        ),
      );

  testWidgets('of exposes the repository to descendants', (tester) async {
    final repository = repo();
    late EngramRepository found;
    await tester.pumpWidget(scoped(repository, (r) => found = r));
    expect(found, same(repository));
  });

  testWidgets('a changed repository notifies dependents', (tester) async {
    final a = repo();
    final b = repo();
    late EngramRepository found;
    await tester.pumpWidget(scoped(a, (r) => found = r));
    expect(found, same(a));

    await tester.pumpWidget(scoped(b, (r) => found = r));
    expect(found, same(b)); // updateShouldNotify → true → dependent rebuilt
  });
}
