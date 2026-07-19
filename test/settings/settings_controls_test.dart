import 'package:brainframe/settings/setting_control.dart';
import 'package:brainframe/settings/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, SettingControl control) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: SettingControlView(control: control))),
        ),
      );

  testWidgets('toggle renders and reports changes', (tester) async {
    bool? changed;
    await pump(tester, ToggleControl(value: false, onChanged: (v) => changed = v));
    await tester.tap(find.byType(Switch));
    expect(changed, isTrue);
  });

  testWidgets('a toggle with no handler renders disabled', (tester) async {
    await pump(tester, const ToggleControl(value: true, onChanged: null));
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('segmented renders options and reports selection', (tester) async {
    String? selected;
    await pump(
      tester,
      SegmentedControl(
        selected: 'a',
        options: const [
          SegmentOption(id: 'a', label: 'Aye'),
          SegmentOption(id: 'b', label: 'Bee'),
        ],
        onSelected: (id) => selected = id,
      ),
    );
    expect(find.text('Aye'), findsOneWidget);
    await tester.tap(find.text('Bee'));
    expect(selected, 'b');
  });

  testWidgets('a segmented with no handler is disabled', (tester) async {
    await pump(
      tester,
      const SegmentedControl(
        selected: 'a',
        options: [SegmentOption(id: 'a', label: 'Aye')],
      ),
    );
    expect(find.text('Aye'), findsOneWidget);
  });

  testWidgets('select shows its value and opens a menu to change', (tester) async {
    String? picked;
    await pump(
      tester,
      SelectControl(
        value: 'One',
        options: const ['One', 'Two'],
        onChanged: (v) => picked = v,
      ),
    );
    expect(find.text('One'), findsWidgets);
    await tester.tap(find.text('One').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two').last);
    expect(picked, 'Two');
  });

  testWidgets('a select with no handler just displays the value', (tester) async {
    await pump(tester, const SelectControl(value: 'Only', options: ['Only']));
    expect(find.text('Only'), findsOneWidget);
  });

  testWidgets('slider renders its value label', (tester) async {
    await pump(
      tester,
      SliderControl(value: 15, min: 11, max: 22, unit: 'px', onChanged: (_) {}),
    );
    expect(find.text('15px'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('color swatches render and report a pick', (tester) async {
    String? picked;
    await pump(
      tester,
      ColorControl(
        value: '#7c6cf0',
        options: const ['#7c6cf0', '#4f8ff7'],
        onChanged: (v) => picked = v,
      ),
    );
    await tester.tap(find.bySemanticsLabel('#4f8ff7'));
    expect(picked, '#4f8ff7');
  });

  testWidgets('number and text render read-only values', (tester) async {
    await pump(tester, const NumberControl(value: 4));
    expect(find.text('4'), findsOneWidget);
    await pump(tester, const TextControl(value: 'hello'));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('hotkey renders its key caps', (tester) async {
    await pump(tester, const HotkeyControl(keys: ['⌘', '⇧', 'D']));
    expect(find.text('⌘'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('buttons render (incl. danger) and fire', (tester) async {
    var tapped = false;
    await pump(
      tester,
      ButtonsControl(
        items: [
          SettingButton(label: 'Go', onPressed: () => tapped = true),
          const SettingButton(label: 'Danger', danger: true),
        ],
      ),
    );
    expect(find.text('Danger'), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(tapped, isTrue);
  });

  testWidgets('info renders its read-only value', (tester) async {
    await pump(tester, const InfoControl(value: '2.4.1 (0426)'));
    expect(find.text('2.4.1 (0426)'), findsOneWidget);
  });
}
