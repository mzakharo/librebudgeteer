import 'package:flutter/material.dart';

import '../globals.dart' as globals;

class AboutAppListTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AboutListTile(
      icon: const Icon(Icons.info),
      child: const Text('About'),
      applicationIcon: Image.asset(
        'assets/icon/launcher_icon.png',
        height: 75,
        width: 75,
      ),
      applicationLegalese: 'Made by Mikhail Zakharov',
      applicationVersion: globals.version,
      aboutBoxChildren: <Widget>[
        const SizedBox(height: 12),
        const Text('A beautiful and informative budgeting app'),
        const SizedBox(height: 7),
      ],
    );
  }
}
