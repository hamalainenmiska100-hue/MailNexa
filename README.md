# Mailnexa

Mailnexa is now a plain **HTML/CSS/JavaScript** temporary inbox client that talks directly to `mail.tm`.

## Local development

Because the app is static, you can serve the `web/` folder with any static server:

```bash
python3 -m http.server 8080 --directory web
```

Then open `http://localhost:8080`.

## GitHub Pages deployment

A GitHub Actions workflow is included at `.github/workflows/deploy-gh-pages.yml`.

- Push to `main` (or run it manually from **Actions**).
- The workflow uploads the `web/` directory directly.
- GitHub Pages serves it as a static site (no Flutter build step).
