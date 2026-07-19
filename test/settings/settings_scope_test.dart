import 'package:brainframe/settings/settings_scope.dart';
import 'package:brainframe/settings/settings_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _MapBackend implements SettingsBackend {
  final Map<String, Object?> values = {};
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object? value) async {
    values[key] = value;
  }
}

void main() {
  SettingsStore storeOver(_MapBackend device) =>
      SettingsStore(device: device, engram: () => const NullSettingsBackend());

  testWidgets('maybeOf returns null with no ancestor', (tester) async {
    SettingsStore? found = storeOver(_MapBackend()); // sentinel: expect cleared
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          found = SettingsScope.maybeOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(found, isNull);
  });

  testWidgets('of exposes the store to descendants', (tester) async {
    final store = storeOver(_MapBackend());
    late SettingsStore found;
    await tester.pumpWidget(
      SettingsScope(
        store: store,
        child: Builder(
          builder: (context) {
            found = SettingsScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, same(store));
  });

  testWidgets('a declared setting round-trips through the scoped store',
      (tester) async {
    final device = _MapBackend();
    final flag = Setting.boolean(
      key: 'demo.flag',
      tier: SettingTier.device,
      defaultValue: false,
    );
    late SettingsStore store;
    await tester.pumpWidget(
      SettingsScope(
        store: storeOver(device),
        child: Builder(
          builder: (context) {
            store = SettingsScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(await store.read(flag), isFalse); // default
    await store.write(flag, true);
    expect(await store.read(flag), isTrue);
    expect(device.values['demo.flag'], isTrue); // reached the backend
  });
}
