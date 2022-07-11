import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:flutter/material.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:window_size/window_size.dart';


extension Choice<T> on List<T> {
  T choice() {
    final random = Random();
    return this[random.nextInt(length)];
  }
}


String cmdname() {
  var cmd = Platform.resolvedExecutable;
  return cmd.split(Platform.pathSeparator).last;
}


bool isDesktop() {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}


void printHelp(ArgParser parser, {bool doExit=true}) {
  const String about = 'the Brain Frame: A tool to help you manage all the '
      'information you try to keep in your brain.';

  print('\n$about\n\n${cmdname()} [options]\n${parser.usage}\n');

  if (doExit) {
    exit(0);
  }
}


void main(List<String> args) {
  var parser = ArgParser();
  parser.addFlag('help', abbr:'h', negatable: false);
  var results = parser.parse(args);
  if (results['help']) {
    printHelp(parser);
  }

  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktop()) {
    setWindowTitle("Brain Frame");
  }
  runApp(const BrainFrameApp());
}


class BrainFrameApp extends StatelessWidget {
  const BrainFrameApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brain Frame',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Brain Frame - Uplifts'),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}


class _MyHomePageState extends State<MyHomePage> {
  final _uplifts = [
    "I am a self-reliant individual.",
    "I maintain my physical health.",
    "I maintain my mental health.",
  ];
  String? _uplift;
  Timer? updateTimer;

  _MyHomePageState():super() {
    KeepScreenOn.turnOn();

    _uplift ??= _uplifts.choice();

    updateTimer ??= Timer.periodic(
        const Duration(seconds:60), (timer) {
      _uplift = _uplifts.choice();
      setState(() {});
    });
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    super.dispose();
  }

  void _updateUplift() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_uplift ?? "Unassigned",
              style: Theme.of(context).textTheme.headline4,
              key: const Key("uplift_message"),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateUplift,
        tooltip: 'Update Uplift Now',
        child: const Icon(Icons.update),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
