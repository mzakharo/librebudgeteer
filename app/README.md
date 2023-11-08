# budget flutter app

Setup:

 - create a 'secrets.dart' file inside 'lib' folder with the following contents

```
String influx_url = "http://your-influx-url.com:8086";
String influx_org = "some_org";
String influx_token = "token";
String influx_bucket = "bucket";

String notion_secret = "secret_XXX";
String notion_database = "DB_UUID";

```

 - Install flutter. run `flutter doctor` to make sure everything is kosher.
 
 Built with:
 
```
Flutter 3.10.6 • channel stable • https://github.com/flutter/flutter.git
Tools • Dart 3.0.6 • DevTools 2.23.1
```

 - Connect Phone via USB, with USB Debugging enabled.

```flutter run```


 - To Release

```make.bat```


App originally sourced from https://github.com/rsquared226/budget_my_life