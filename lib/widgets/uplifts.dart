import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keep_screen_on/keep_screen_on.dart';

import 'package:brainframe/extensions/list.dart';
import 'package:brainframe/platform.dart';
import 'package:brainframe/config.dart';

class Uplifts extends StatefulWidget {
  const Uplifts({Key? key}) : super(key: key);

  @override
  State<Uplifts> createState() => _UpliftsState();
}

class _UpliftsState extends State<Uplifts> {
  String? _uplift;
  Timer? updateTimer;

  _UpliftsState() : super() {
    _uplift ??= uplifts.choice();

    if (!isDesktop()) {
      KeepScreenOn.turnOn();
    }

    updateTimer ??= Timer.periodic(const Duration(seconds: upliftTimer), (timer) {
      _updateUplift();
    });
  }

  @override
  void dispose() {
    if (!isDesktop()) {
      KeepScreenOn.turnOff();
    }

    updateTimer?.cancel();
    super.dispose();
  }

  void _updateUplift() {
    _uplift = uplifts.choice();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Text(
        _uplift ?? "Unassigned",
        style: Theme.of(context).textTheme.headline4,
      ),
      FloatingActionButton(
        onPressed: _updateUplift,
        tooltip: 'Update Uplift Now',
        child: const Icon(Icons.update),
      ),
    ]);
  }
}
