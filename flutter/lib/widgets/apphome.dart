import 'package:flutter/material.dart';

import 'package:brainframe/widgets/uplifts.dart';

class BrainFrameApp extends StatelessWidget {
  const BrainFrameApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brain Frame',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BrainFrameHomePage(title: 'Brain Frame'),
    );
  }
}

class BrainFrameHomePage extends StatefulWidget {
  const BrainFrameHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<BrainFrameHomePage> createState() => _BrainFrameHomePageState();
}

class _BrainFrameHomePageState extends State<BrainFrameHomePage> {
  static const key = Key('uplifts_widget');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Uplifts(),
          ],
        ),
      ),
    );
  }
}
