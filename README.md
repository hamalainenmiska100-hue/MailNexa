# Mailnexa

Mailnexa is a Flutter Web temporary inbox client that talks directly to `mail.tm` from the browser.

## Run locally

```bash
flutter pub get
flutter run -d chrome
```

## Production build

```bash
flutter build web --release
```

Deploy the generated `build/web` directory to static hosting.
