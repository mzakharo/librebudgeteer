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

 - Install flutter. run `flutter doctor -v` to make sure everything is kosher.
 
 Built with:
 
```
Flutter 3.10.6 • channel stable • https://github.com/flutter/flutter.git
Tools • Dart 3.0.6 • DevTools 2.23.1
```

 - Android target: Connect Phone via USB, with USB Debugging enabled: `flutter run`
 - Android build release APK: `flutter build apk --release`

 - Windows target: `flutter run -d windows`
 - Linux target: `flutter run -d linux`
 - Web\Chrome target: `flutter run -d chrome`
   - Due to dependency on notion.so, CORS must be [disabled](https://stackoverflow.com/questions/65630743/how-to-solve-flutter-web-api-cors-error-only-with-dart-code) for budgets to work in the app.

App originally sourced from https://github.com/rsquared226/budget_my_life
