# Release Process

Complete guide for managing releases, versioning, and changelog generation.

## Table of Contents

1. [Version Management](#version-management)
2. [Version Bumping](#version-bumping)
3. [Changelog Generation](#changelog-generation)
4. [Release Checklist](#release-checklist)
5. [Release Workflow](#release-workflow)

---

## Version Management

### Version Format

The app version is defined in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`

- **MAJOR**: Breaking changes, major feature releases
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes, minor improvements
- **BUILD_NUMBER**: Incremental build number (required by stores)

### Semantic Versioning

Follow [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0): Incompatible API changes
- **MINOR** (1.0.0 → 1.1.0): New functionality (backward compatible)
- **PATCH** (1.0.0 → 1.0.1): Bug fixes (backward compatible)

### Build Number Rules

- **Android**: Must be unique and incrementing for each release
- **iOS**: Must be unique and incrementing for each release
- **Best Practice**: Increment build number for every build, even if version doesn't change

---

## Version Bumping

### Automated Bumping

Use the provided script:

```bash
./scripts/bump_version.sh [major|minor|patch] [build_number]
```

**Examples**:

```bash
# Bump patch version (1.0.0+1 → 1.0.1+2)
./scripts/bump_version.sh patch

# Bump minor version (1.0.0+1 → 1.1.0+2)
./scripts/bump_version.sh minor

# Bump major version (1.0.0+1 → 2.0.0+2)
./scripts/bump_version.sh major

# Set specific build number (1.0.0+1 → 1.0.0+42)
./scripts/bump_version.sh patch 42

# Keep version, only bump build (1.0.0+1 → 1.0.0+2)
./scripts/bump_version.sh build
```

### Manual Bumping

1. Edit `pubspec.yaml`:
```yaml
version: 1.0.1+2  # Update version and build number
```

2. Update version in platform-specific files if needed:
   - **Android**: Usually handled automatically
   - **iOS**: Usually handled automatically

---

## Changelog Generation

### Conventional Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Commit Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes
- `build`: Build system changes
- `revert`: Revert previous commit

### Examples

```bash
feat(auth): Add email verification
fix(api): Handle network timeout errors
docs(readme): Update installation instructions
refactor(ui): Simplify navigation structure
perf(images): Optimize image loading
test(auth): Add login tests
chore(deps): Update dependencies
```

### Generate Changelog

```bash
./scripts/generate_changelog.sh [version]
```

This script:
1. Reads git commits since last tag
2. Groups by commit type
3. Generates markdown changelog
4. Updates `CHANGELOG.md`

### Changelog Format

```markdown
# Changelog

## [1.0.1] - 2024-01-15

### Added
- Email verification feature
- Dark mode support

### Changed
- Improved error handling
- Updated dependencies

### Fixed
- Network timeout issues
- Memory leak in image loading

### Security
- Fixed authentication vulnerability
```

---

## Release Checklist

### Pre-Release

- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] Dependencies updated and tested
- [ ] Version bumped in `pubspec.yaml`
- [ ] Changelog generated and reviewed
- [ ] Documentation updated
- [ ] Build tested on all platforms
- [ ] Environment variables verified
- [ ] Release notes prepared

### Android Specific

- [ ] App bundle built successfully
- [ ] App bundle tested locally
- [ ] Play Console listing updated
- [ ] Screenshots updated (if needed)
- [ ] Release notes added
- [ ] Content rating up to date

### iOS Specific

- [ ] IPA built successfully
- [ ] TestFlight tested (if applicable)
- [ ] App Store Connect listing updated
- [ ] Screenshots updated (if needed)
- [ ] App Review information updated
- [ ] Privacy policy URL verified

### Web Specific

- [ ] Web build tested
- [ ] All routes working
- [ ] SEO meta tags updated
- [ ] Analytics configured
- [ ] CDN configured (if applicable)

---

## Release Workflow

### 1. Prepare Release Branch

```bash
# Create release branch
git checkout -b release/v1.0.1

# Make final changes
# - Bump version
# - Update changelog
# - Update documentation

# Commit changes
git add .
git commit -m "chore: prepare release v1.0.1"
```

### 2. Create Release Tag

```bash
# Tag the release
git tag -a v1.0.1 -m "Release v1.0.1"

# Push branch and tag
git push origin release/v1.0.1
git push origin v1.0.1
```

### 3. Trigger CI/CD

The CI/CD workflows automatically trigger on tag push:

- **Android**: Builds and uploads to Play Store
- **iOS**: Builds and uploads to App Store Connect
- **Web**: Builds and deploys to hosting

### 4. Monitor Deployment

- Check GitHub Actions for build status
- Monitor Play Console / App Store Connect
- Verify deployment success

### 5. Merge to Main

```bash
# After successful deployment
git checkout main
git merge release/v1.0.1
git push origin main
```

### 6. Create GitHub Release

1. Go to GitHub → Releases → Draft a new release
2. Select tag: `v1.0.1`
3. Title: `Release v1.0.1`
4. Description: Copy from `CHANGELOG.md`
5. Attach build artifacts (optional)
6. Publish release

---

## Hotfix Process

For urgent bug fixes:

### 1. Create Hotfix Branch

```bash
# From main branch
git checkout -b hotfix/v1.0.2
```

### 2. Fix and Test

```bash
# Make fix
# Test thoroughly
# Bump patch version
./scripts/bump_version.sh patch
```

### 3. Release

```bash
# Tag and push
git tag -a v1.0.2 -m "Hotfix v1.0.2"
git push origin hotfix/v1.0.2
git push origin v1.0.2
```

### 4. Merge Back

```bash
# Merge to main
git checkout main
git merge hotfix/v1.0.2
git push origin main

# Merge to develop (if exists)
git checkout develop
git merge hotfix/v1.0.2
git push origin develop
```

---

## Version Strategy

### Development

- Use `-dev` suffix: `1.0.0-dev+1`
- Increment build number frequently
- Don't worry about version for dev builds

### Staging

- Use `-staging` suffix: `1.0.0-staging+1`
- Match production version when possible
- Test with production-like configuration

### Production

- Clean version numbers: `1.0.0+1`
- Follow semantic versioning strictly
- Document all changes in changelog

---

## Automated Release

### Using GitHub Actions

The release workflow can be automated:

1. **Create Release PR**: Automated PR with version bump
2. **Review and Merge**: Manual review required
3. **Auto-Tag**: Creates tag on merge
4. **Auto-Build**: Builds and deploys automatically
5. **Auto-Release**: Creates GitHub release

### Release Script

See `scripts/release.sh` for complete release automation.

---

## Best Practices

1. **Always bump build number**: Even for patch releases
2. **Document changes**: Keep changelog up to date
3. **Test before release**: Always test on all platforms
4. **Staged rollouts**: Start with small percentage
5. **Monitor after release**: Watch for crashes and issues
6. **Version consistency**: Keep versions in sync across platforms
7. **Tag every release**: Makes it easy to track releases

---

## Troubleshooting

### Version Mismatch

**Issue**: Version in `pubspec.yaml` doesn't match store

**Solution**: 
- Update `pubspec.yaml`
- Rebuild and resubmit

### Build Number Conflict

**Issue**: Build number already used in store

**Solution**:
- Increment build number
- Rebuild and resubmit

### Changelog Not Generated

**Issue**: Script fails to generate changelog

**Solution**:
- Check git tags exist
- Verify commit format
- Check script permissions

---

## Resources

- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Keep a Changelog](https://keepachangelog.com/)

