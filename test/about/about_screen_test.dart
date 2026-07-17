import 'dart:async';
import 'dart:io';

import 'package:brainframe/about/about_screen.dart';
import 'package:brainframe/theme/app_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/localized_app.dart';

/// A minimal manifest exposing just the logo asset so `Image.asset` can resolve
/// its (single, main) variant in tests without a real AssetManifest.bin.
class _LogoManifest implements AssetManifest {
  const _LogoManifest();

  @override
  List<String> listAssets() => const ['brainframe.png'];

  @override
  List<AssetMetadata> getAssetVariants(String key) => const [
        AssetMetadata(
          key: 'brainframe.png',
          targetDevicePixelRatio: null,
          main: true,
        ),
      ];
}

/// Serves the real `brainframe.png` bytes so the About screen's logo resolves
/// in widget tests (the manifest lookup would otherwise throw).
class _LogoBundle extends CachingAssetBundle {
  _LogoBundle(this._png);
  final Uint8List _png;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(_png);

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) async {
    if (key == 'AssetManifest.bin') return const _LogoManifest() as T;
    return super.loadStructuredBinaryData(key, parser);
  }
}

void main() {
  final logoBytes = File('brainframe.png').readAsBytesSync();

  /// Wraps [child] with app settings (for AppScaffold), the localizations, and
  /// a bundle that can serve the logo. AppSettings sits above the MaterialApp,
  /// as in the real app, so pushed routes see it too.
  Widget host(Widget child, {Locale? locale}) => DefaultAssetBundle(
        bundle: _LogoBundle(logoBytes),
        child: AppSettings(
          child: localizedApp(home: child, locale: locale),
        ),
      );

  Widget screen({
    UriLauncher? launcher,
    int? year,
  }) =>
      AboutScreen(
        version: '2.4.1',
        buildNumber: '1847',
        launcher: launcher ?? (_) async => true,
        year: year,
      );

  testWidgets('shows app identity and tagline', (tester) async {
    await tester.pumpWidget(host(screen()));

    expect(find.text('BrainFrame'), findsOneWidget);
    expect(
      find.textContaining('personal knowledge management'),
      findsOneWidget,
    );
  });

  testWidgets('version pill shows version, build, and a screen-reader label',
      (tester) async {
    await tester.pumpWidget(host(screen()));

    // The pill renders as rich text: 'v2.4.1 · build 1847'.
    expect(
      find.textContaining('v2.4.1', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('build 1847', findRichText: true),
      findsOneWidget,
    );
    // The visual pill is excluded from semantics in favour of a clean label.
    expect(find.bySemanticsLabel('Version 2.4.1, build 1847'), findsOneWidget);
  });

  testWidgets('website row launches the site in the external browser',
      (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(host(screen(launcher: (uri) async {
      launched.add(uri);
      return true;
    })));

    await tester.ensureVisible(find.text('brainframe.tech'));
    await tester.tap(find.text('brainframe.tech'));
    await tester.pump();

    expect(launched, [Uri.parse('https://brainframe.tech/')]);
  });

  testWidgets('contact row launches a mailto link', (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(host(screen(launcher: (uri) async {
      launched.add(uri);
      return true;
    })));

    await tester.ensureVisible(find.text('getbrainframe@gmail.com'));
    await tester.tap(find.text('getbrainframe@gmail.com'));
    await tester.pump();

    expect(launched, [Uri.parse('mailto:getbrainframe@gmail.com')]);
  });

  testWidgets('link rows expose combined button semantics', (tester) async {
    await tester.pumpWidget(host(screen()));

    expect(
      find.bySemanticsLabel('Website: brainframe.tech'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Contact: getbrainframe@gmail.com'),
      findsOneWidget,
    );
  });

  testWidgets('footer shows the given year', (tester) async {
    await tester.pumpWidget(host(screen(year: 2031)));

    expect(find.textContaining('© 2031 BrainFrame'), findsOneWidget);
  });

  testWidgets('footer defaults to the current year when none is given',
      (tester) async {
    await tester.pumpWidget(host(screen()));

    final thisYear = DateTime.now().year;
    expect(find.textContaining('© $thisYear BrainFrame'), findsOneWidget);
  });

  testWidgets('renders inside the Cupertino scaffold too', (tester) async {
    await tester.pumpWidget(
      host(
        CupertinoTheme(
          data: const CupertinoThemeData(),
          child: MediaQuery(
            data: const MediaQueryData(platformBrightness: Brightness.dark),
            child: screen(),
          ),
        ),
      ),
    );

    // AppScaffold heading still resolves regardless of design language.
    expect(find.text('About'), findsWidgets);
  });

  testWidgets('openAboutScreen pushes the About screen with real app info',
      (tester) async {
    Future<PackageInfo> fakeInfo() async => PackageInfo(
          appName: 'BrainFrame',
          packageName: 'tech.brainframe.app',
          version: '9.9.9',
          buildNumber: '4242',
        );

    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openAboutScreen(context, loadInfo: fakeInfo),
                child: const Text('open about'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open about'));
    await tester.pumpAndSettle();

    expect(find.text('BrainFrame'), findsWidgets);
    expect(find.bySemanticsLabel('Version 9.9.9, build 4242'), findsOneWidget);
  });
}
