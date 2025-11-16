# Deployment Documentation

Complete deployment documentation for Flutter Starter across all platforms.

## Quick Start

1. **Read the main guide**: [deployment.md](./deployment.md)
2. **Platform-specific guides**:
   - [Android Deployment](./android-deployment.md)
   - [iOS Deployment](./ios-deployment.md)
   - [Web Deployment](./web-deployment.md)
3. **Release process**: [release-process.md](./release-process.md)
4. **Monitoring setup**: [monitoring-analytics.md](./monitoring-analytics.md)

## Documentation Structure

```
docs/deployment/
├── README.md                 # This file
├── deployment.md             # Main deployment guide
├── android-deployment.md     # Android-specific guide
├── ios-deployment.md         # iOS-specific guide
├── web-deployment.md         # Web-specific guide
├── release-process.md        # Release workflow
└── monitoring-analytics.md   # Monitoring setup
```

## CI/CD Workflows

GitHub Actions workflows are located in `.github/workflows/`:

- **ci.yml**: Continuous integration (tests, builds)
- **deploy-android.yml**: Android deployment to Play Store
- **deploy-ios.yml**: iOS deployment to App Store
- **deploy-web.yml**: Web deployment to hosting platforms

## Helper Scripts

Scripts are located in `scripts/`:

- **bump_version.sh**: Bump version in pubspec.yaml
- **generate_changelog.sh**: Generate changelog from git commits
- **release.sh**: Complete release automation
- **build_all.sh**: Build for all platforms

## Getting Help

- Check platform-specific guides for detailed instructions
- Review [Troubleshooting Guide](../guides/troubleshooting.md)
- Check GitHub Actions logs for CI/CD issues

## Next Steps

1. Set up code signing (Android & iOS)
2. Configure GitHub Actions secrets
3. Set up Firebase projects
4. Test build process locally
5. Create your first release

