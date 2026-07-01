import 'package:brainframe/theme/app_settings.dart';
import 'package:brainframe/theme/design_language.dart';
import 'package:brainframe/widgets/app_scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required DesignLanguage design,
  List<Widget>? actions,
}) {
  return MaterialApp(
    home: AppSettings(
      designOverride: design,
      child: AppScaffold(
        title: 'Title',
        actions: actions,
        body: const Text('Body'),
      ),
    ),
  );
}

void main() {
  testWidgets('Material design renders a Scaffold + AppBar', (tester) async {
    await tester.pumpWidget(_host(design: DesignLanguage.material));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('Cupertino design renders a CupertinoPageScaffold',
      (tester) async {
    await tester.pumpWidget(_host(design: DesignLanguage.cupertino));

    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('Cupertino trailing appears only when actions are given',
      (tester) async {
    await tester.pumpWidget(
      _host(
        design: DesignLanguage.cupertino,
        actions: const [Icon(CupertinoIcons.add)],
      ),
    );

    expect(find.byIcon(CupertinoIcons.add), findsOneWidget);
    // The trailing Row is only built when actions are present.
    expect(
      find.descendant(
        of: find.byType(CupertinoNavigationBar),
        matching: find.byType(Row),
      ),
      findsOneWidget,
    );
  });
}
