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

## GitHub Pages auto-deploy

A GitHub Actions workflow is included at `.github/workflows/deploy-gh-pages.yml`.

- Push to `main` (or run it manually from **Actions**)
- The workflow runs `flutter build web --release`
- It deploys `build/web` to GitHub Pages automatically
