import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as urlLauncher;

import '../globals.dart' as globals;

class AboutAppListTile extends StatelessWidget {
  Future<void> launchUrl(BuildContext context, String url) async {
    if (await urlLauncher.canLaunch(url)) {
      await urlLauncher.launch(url);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Could not open URL'),
            content: Text(url + ' could not be opened'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('GOT IT'),
              ),
            ],
          );
        },
      );
    }
  }

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
