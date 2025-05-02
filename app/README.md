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
 - run `flutter doctor -v` . Tested environment:

 ```
 [√] Flutter (Channel stable, 3.29.3)
    • Engine revision cf56914b32
    • Dart version 3.7.2
    • DevTools version 2.42.3

[√] Android Studio (version 2024.3) [28ms]
    • Java version OpenJDK Runtime Environment (build 21.0.6+-13355223-b631.42)
 ```
 
Build Targets:

 - Android Debug: Connect Phone via USB, with USB Debugging enabled: `flutter run`
 - Android release: `flutter build apk --release`
 - Windows: `flutter run -d windows`

Inspired by https://github.com/rsquared226/budget_my_life
