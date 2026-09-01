# LinkSo Client

The Flutter Web, Android and iOS application for creating, managing and tracking LinkSo short links.

## Run

Requires Flutter 3.47 / Dart 3.13 and a running LinkSo API. From this directory:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Replace the API URL with an address reachable from the selected device. Web cookie authentication requires the client and API to be served from the same origin; use the repository Docker stack for that mode.
