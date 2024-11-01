# budget flutter app

Setup:

 - create a `secrets.dart` file inside `lib` folder with the following contents

```
String influx_url = "http://your-influx-url.com:8086";
String influx_org = "some_org";
String influx_token = "token";
String influx_bucket = "bucket";

String notion_secret = "secret_XXX";
String notion_database = "DB_BUDGETS_UUID";

```

 - [Install](https://docs.flutter.dev/get-started/install) flutter.
 - run `flutter doctor -v` to make sure everything is kosher.
 
This App was tested with:
 
```
Flutter 3.24.4 • channel stable • https://github.com/flutter/flutter.git
Engine • revision db49896cf2
Tools • Dart 3.5.4 • DevTools 2.37.3
```

Build Targets:

 - Android Debug: Connect Phone via USB, with USB Debugging enabled: `flutter run`
 - Android release: `flutter build apk --release`
 - Windows: `flutter run -d windows`
 - Linux: `flutter run -d linux`
 - Web\Chrome: `flutter run -d chrome`
   - Due to dependency on notion.so, CORS must be [disabled](https://stackoverflow.com/questions/65630743/how-to-solve-flutter-web-api-cors-error-only-with-dart-code) for budgets to work in the app.

App originally sourced from https://github.com/rsquared226/budget_my_life
