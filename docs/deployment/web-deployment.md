# Web Deployment Guide

Complete guide for deploying Flutter Starter web app to various hosting platforms.

## Prerequisites

- Flutter SDK with web support enabled
- Node.js and npm (for some hosting platforms)
- Account on hosting platform of choice

## Step 1: Build Web App

### Development Build

```bash
flutter build web \
  --dart-define=ENVIRONMENT=development \
  --dart-define=BASE_URL=http://localhost:3000
```

### Production Build

```bash
flutter build web \
  --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=BASE_URL=https://api.example.com \
  --web-renderer canvaskit
```

**Build Output**: `build/web/`

### Build Options

- `--web-renderer canvaskit`: Better compatibility, larger bundle
- `--web-renderer html`: Smaller bundle, better performance (experimental)
- `--base-href /`: Set base URL for deployment

## Step 2: Test Locally

### Using Flutter

```bash
flutter run -d chrome --web-port=8080
```

### Using Local Server

```bash
# Python
cd build/web
python3 -m http.server 8080

# Node.js
npx http-server build/web -p 8080

# PHP
cd build/web
php -S localhost:8080
```

Visit `http://localhost:8080` to test.

## Step 3: Choose Hosting Platform

### Firebase Hosting (Recommended)

Best for: Quick setup, CDN, custom domains, SSL

### Netlify

Best for: Git-based deployments, preview deployments, forms

### Vercel

Best for: Next.js-like experience, edge functions, analytics

### GitHub Pages

Best for: Free hosting, simple setup, public repos

### AWS Amplify

Best for: AWS integration, CI/CD, advanced features

### Custom Server

Best for: Full control, existing infrastructure

## Firebase Hosting

### Setup

1. **Install Firebase CLI**:
```bash
npm install -g firebase-tools
```

2. **Login**:
```bash
firebase login
```

3. **Initialize Firebase**:
```bash
firebase init hosting
```

Select:
- Use existing project or create new
- Public directory: `build/web`
- Single-page app: Yes
- Set up automatic builds: Yes (optional)

### Configuration

Create `firebase.json`:

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|woff|woff2|ttf|otf|eot)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

### Deploy

```bash
# Build first
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### Custom Domain

1. Go to Firebase Console → Hosting
2. Click "Add custom domain"
3. Follow DNS configuration instructions
4. SSL certificate automatically provisioned

## Netlify

### Setup

1. **Install Netlify CLI**:
```bash
npm install -g netlify-cli
```

2. **Login**:
```bash
netlify login
```

### Configuration

Create `netlify.toml`:

```toml
[build]
  publish = "build/web"
  command = "flutter build web --release"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[build.environment]
  FLUTTER_VERSION = "stable"
```

### Deploy

```bash
# Build and deploy
netlify deploy --prod

# Or connect to Git for automatic deployments
netlify init
```

### Git Integration

1. Go to Netlify Dashboard
2. Add new site → Import from Git
3. Connect repository
4. Configure build settings:
   - Build command: `flutter build web --release`
   - Publish directory: `build/web`
5. Deploy automatically on push

## Vercel

### Setup

1. **Install Vercel CLI**:
```bash
npm install -g vercel
```

2. **Login**:
```bash
vercel login
```

### Configuration

Create `vercel.json`:

```json
{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "build/web"
      }
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ]
}
```

Create `package.json` (if not exists):

```json
{
  "name": "flutter_starter",
  "version": "1.0.0",
  "scripts": {
    "build": "flutter build web --release"
  }
}
```

### Deploy

```bash
vercel --prod
```

### Git Integration

1. Go to Vercel Dashboard
2. Import Git Repository
3. Configure project:
   - Framework Preset: Other
   - Build Command: `flutter build web --release`
   - Output Directory: `build/web`
4. Deploy automatically on push

## GitHub Pages

### Setup

1. **Build web app**:
```bash
flutter build web --release --base-href /flutter_starter/
```

2. **Push to GitHub**:
```bash
git subtree push --prefix build/web origin gh-pages
```

### Configuration

Create `.github/workflows/deploy-web.yml`:

```yaml
name: Deploy Web

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
      - run: flutter pub get
      - run: flutter build web --release --base-href /flutter_starter/
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

### Enable GitHub Pages

1. Go to Repository Settings → Pages
2. Source: Deploy from branch
3. Branch: `gh-pages` / `root`
4. Save

Your app will be available at:
`https://<username>.github.io/<repository-name>/`

## AWS Amplify

### Setup

1. Go to [AWS Amplify Console](https://console.aws.amazon.com/amplify)
2. New app → Host web app
3. Connect repository or deploy without Git

### Configuration

Create `amplify.yml`:

```yaml
version: 1
frontend:
  phases:
    preBuild:
      commands:
        - echo "Installing Flutter..."
        - curl -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.x.x-stable.tar.xz
        - tar xf flutter.tar.xz
        - export PATH="$PATH:`pwd`/flutter/bin"
        - flutter --version
        - flutter pub get
    build:
      commands:
        - flutter build web --release
  artifacts:
    baseDirectory: build/web
    files:
      - '**/*'
  cache:
    paths:
      - .dart_tool/pub-cache/**
```

## Custom Server (Nginx)

### Configuration

Create `/etc/nginx/sites-available/flutter_starter`:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /var/www/flutter_starter/build/web;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

### Deploy

```bash
# Build
flutter build web --release

# Copy to server
scp -r build/web/* user@server:/var/www/flutter_starter/build/web/

# Reload Nginx
ssh user@server "sudo nginx -t && sudo systemctl reload nginx"
```

## Environment Configuration

### Build-Time Variables

Use `--dart-define` for environment-specific builds:

```bash
flutter build web --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=BASE_URL=https://api.example.com \
  --dart-define=ENABLE_ANALYTICS=true
```

### Runtime Configuration

For runtime configuration, use a config file:

```dart
// lib/core/config/runtime_config.dart
class RuntimeConfig {
  static Future<void> load() async {
    final response = await http.get(Uri.parse('/config.json'));
    final config = jsonDecode(response.body);
    // Apply configuration
  }
}
```

Create `web/config.json`:

```json
{
  "environment": "production",
  "baseUrl": "https://api.example.com",
  "enableAnalytics": true
}
```

## Performance Optimization

### Code Splitting

Flutter web automatically splits code. For manual control:

```dart
// Use deferred imports
import 'package:my_package/my_package.dart' deferred as myPackage;

Future<void> loadFeature() async {
  await myPackage.loadLibrary();
  myPackage.useFeature();
}
```

### Asset Optimization

1. **Compress images**: Use WebP format
2. **Lazy load**: Load assets on demand
3. **CDN**: Use CDN for static assets

### Build Optimization

```bash
# Use HTML renderer for smaller bundle
flutter build web --release --web-renderer html

# Or optimize CanvasKit
flutter build web --release --web-renderer canvaskit --dart-define=FLUTTER_WEB_USE_SKIA=false
```

## Troubleshooting

### Routing Issues

**404 on refresh**:
- Configure server to serve `index.html` for all routes
- Use `--base-href` flag for subdirectory deployments

### CORS Issues

**API requests blocked**:
- Configure CORS on backend
- Or use proxy in hosting configuration

### Performance Issues

**Slow loading**:
- Enable gzip compression
- Use CDN for assets
- Optimize images
- Consider code splitting

## Best Practices

1. **Always use HTTPS**: Required for many web APIs
2. **Set proper cache headers**: Improve performance
3. **Monitor performance**: Use Lighthouse, WebPageTest
4. **Test on multiple browsers**: Chrome, Firefox, Safari, Edge
5. **Responsive design**: Test on mobile devices
6. **SEO optimization**: Add meta tags, structured data
7. **Error handling**: Graceful degradation for unsupported features

## Resources

- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Netlify Documentation](https://docs.netlify.com)
- [Vercel Documentation](https://vercel.com/docs)
- [GitHub Pages](https://pages.github.com)

