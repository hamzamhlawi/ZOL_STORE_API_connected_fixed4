# ZOL STORE — API connected Flutter source

This source is configured to use Flutter's modern Android embedding (v2), with a `MainActivity.kt` extending `io.flutter.embedding.android.FlutterActivity`.

API base: `http://node3.serverix.cloud:3145`
- GET `/api/products`
- POST `/api/orders`

## Android project note
For the most reliable build on GitHub Actions, generate the platform wrapper files with Flutter:
`flutter create --platforms=android .`
Then run `flutter pub get` and `flutter build apk --release`.
This ensures the Gradle wrapper scripts and wrapper JAR are present for the Flutter version installed by the build runner.

## Security
The current API URL is plain HTTP for testing only. Use HTTPS before handling customer data. Never include Telegram bot tokens or admin keys in the Flutter app. Prices returned as null will display as unspecified until populated in the server database. Sending a request does not mean payment or delivery has been completed.
