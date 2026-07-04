import 'package:brainframe/engram/asset_engram_store.dart';
import 'package:brainframe/engram/built_in_engrams.dart';
import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:brainframe/engram/engram_scope.dart';
import 'package:brainframe/engram/ui/engram_browser.dart';
import 'package:brainframe/theme/app_settings.dart';
import 'package:brainframe/theme/design_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_asset_bundle.dart';
import '../../support/localized_app.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  // A built-in engram whose one page is translated for en_XA — a real supported
  // locale, so Localizations.localeOf resolves to it (an untranslated language
  // like `es` would fall back to `en` before ever reaching content).
  final bundle = FakeAssetBundle({
    'builtin/en/welcome.md': 'English welcome',
    'builtin/en_XA/welcome.md': 'Pseudo welcome',
  });
  Engram engram() => Engram(
        id: builtinTutorialId,
        displayName: 'Tutorial',
        readOnly: true,
        store: AssetEngramStore(assetPrefix: 'builtin/', bundle: bundle),
      );
  EngramRepository repo() => EngramRepository(
        preferences: SharedPreferencesAsync(),
        containerPathResolver: () async => throw UnsupportedError('no fs'),
      );

  testWidgets('built-in content follows the active locale, reloading on change',
      (tester) async {
    // One home subtree, pumped under two locales: reusing the instance keeps the
    // browser's State so a locale change fires didChangeDependencies (rather
    // than rebuilding from scratch).
    final home = AppSettings(
      designOverride: DesignLanguage.material,
      child: EngramScope(
        initialEngram: engram(),
        child: EngramBrowser(repository: repo()),
      ),
    );

    await tester.pumpWidget(localizedApp(locale: const Locale('en'), home: home));
    await tester.pumpAndSettle();
    expect(find.textContaining('English welcome', findRichText: true),
        findsWidgets);

    await tester.pumpWidget(
      localizedApp(locale: const Locale('en', 'XA'), home: home),
    );
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Pseudo welcome', findRichText: true), findsWidgets);
    expect(find.textContaining('English welcome', findRichText: true),
        findsNothing);
  });
}
