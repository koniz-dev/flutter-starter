#!/bin/bash

# Build script for all platforms
# Usage: ./scripts/ci/build_all.sh [environment] [options]
# Options:
#   --analyze-size    Analyze build size and provide optimization recommendations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
ENVIRONMENT=""
ANALYZE_SIZE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --analyze-size)
      ANALYZE_SIZE=true
      shift
      ;;
    development|staging|production)
      ENVIRONMENT=$1
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: ./scripts/ci/build_all.sh [environment] [--analyze-size]"
      echo "Valid environments: development, staging, production"
      exit 1
      ;;
  esac
done

# Default environment
if [ -z "$ENVIRONMENT" ]; then
  ENVIRONMENT="production"
fi

if [ "$ENVIRONMENT" != "development" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'${NC}"
    echo "Valid environments: development, staging, production"
    exit 1
fi

# Set base URL based on environment
case $ENVIRONMENT in
    development)
        BASE_URL="http://localhost:3000"
        ;;
    staging)
        BASE_URL="${BASE_URL_STAGING:-https://api-staging.example.com}"
        ;;
    production)
        BASE_URL="${BASE_URL_PRODUCTION:-https://api.example.com}"
        ;;
esac

echo -e "${BLUE}Building for environment: $ENVIRONMENT${NC}"
echo "Base URL: $BASE_URL"
echo ""

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
flutter clean
flutter pub get
echo -e "${GREEN}✓ Cleaned${NC}"
echo ""

# Refuse to build a tree that would ship a secrets file.
#
# koniz-dev/flutter-starter#135. The guard already runs in
# scripts/dev/audit_template.sh and, through
# test/tooling/check_env_assets_test.dart, in `flutter test` - but neither of
# those is this path, and this path is the one that produces an artifact. A
# Flutter asset list is not build-mode scoped, so `- .env` under
# `flutter: assets:` ships in the release APK, the release IPA and, worst,
# the web build, where it is served unauthenticated at /assets/.env. The
# common case is a developer who adds that line locally and never commits it:
# CI never sees the edit, so the `flutter test` guard never fires.
#
# It runs after `flutter pub get` because `dart run` needs
# .dart_tool/package_config.json, which `flutter clean` has just deleted, and
# before every build so a failure costs nothing and leaves no artifact behind.
# `set -e` at the top of this script turns its non-zero exit into an abort;
# the explicit `if` is here to say so out loud rather than leaning on it.
echo -e "${YELLOW}Checking for bundled secrets files...${NC}"
if ! dart run tool/check_env_assets.dart; then
    echo -e "${RED}✗ Refusing to build: a secrets file would be bundled as a Flutter asset.${NC}"
    echo "  Remove the entry from pubspec.yaml, or acknowledge it inline -"
    echo "  see docs/guides/configuration.md, 'The deliberate exception, and the guard'."
    exit 1
fi
echo -e "${GREEN}✓ No unacknowledged secrets file in the asset list${NC}"
echo ""

# Build Android
#
# No --flavor anywhere below. ENVIRONMENT here is a --dart-define value read by
# lib/core/config/app_config.dart, NOT a Gradle product flavor: no
# productFlavors are declared in android/app/build.gradle.kts, so passing
# --flavor fails with "Task 'bundleProductionRelease' not found". Issue #34
# removed the flag from the workflows and missed this script (issue #57).
echo -e "${YELLOW}Building Android...${NC}"
if [ "$ENVIRONMENT" == "production" ]; then
    flutter build appbundle \
        --release \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
    echo -e "${GREEN}✓ Android App Bundle built${NC}"
else
    flutter build apk \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
    echo -e "${GREEN}✓ Android APK built${NC}"
fi
echo ""

# Build iOS (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Building iOS...${NC}"
    if [ "$ENVIRONMENT" == "production" ]; then
        flutter build ipa \
            --release \
            --dart-define=ENVIRONMENT=$ENVIRONMENT \
            --dart-define=BASE_URL=$BASE_URL
        echo -e "${GREEN}✓ iOS IPA built${NC}"
    else
        flutter build ios \
            --no-codesign \
            --dart-define=ENVIRONMENT=$ENVIRONMENT \
            --dart-define=BASE_URL=$BASE_URL
        echo -e "${GREEN}✓ iOS build completed${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Skipping iOS build (not on macOS)${NC}"
    echo ""
fi

# Build Web
echo -e "${YELLOW}Building Web...${NC}"
if [ "$ENVIRONMENT" == "production" ]; then
    # --web-renderer was removed from `flutter build web` (see
    # `flutter build web --help`); passing it now aborts the build.
    flutter build web \
        --release \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
else
    flutter build web \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
fi
echo -e "${GREEN}✓ Web build completed${NC}"
echo ""

# Analyze build size if requested
#
# koniz-dev/flutter-starter#335: production builds only an App Bundle, but this
# used to report only an APK, so production reported nothing; the comparison
# bundle was built without the environment's --dart-define values, so it was not
# the configured app; and the advice claimed an ABI split nothing performs.
if [ "$ANALYZE_SIZE" = true ]; then
  echo ""
  echo "🔍 Build Size Analysis"
  echo "================================"
  echo ""

  APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
  BUNDLE_PATH="build/app/outputs/bundle/release/app-release.aab"

  # Production built the bundle above; any other environment gets one built
  # for comparison - with the same defines, so it is the same app.
  if [ "$ENVIRONMENT" != "production" ] || [ ! -f "$BUNDLE_PATH" ]; then
    echo "📦 Building App Bundle (recommended for Play Store)..."
    flutter build appbundle \
        --release \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
  fi

  size_bytes() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null
  }

  APK_SIZE=""
  BUNDLE_SIZE=""
  LARGEST_BYTES=0
  if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    LARGEST_BYTES=$(size_bytes "$APK_PATH")
    echo "📱 APK Size: $APK_SIZE"
  fi
  if [ -f "$BUNDLE_PATH" ]; then
    BUNDLE_SIZE=$(du -h "$BUNDLE_PATH" | cut -f1)
    BUNDLE_BYTES=$(size_bytes "$BUNDLE_PATH")
    if [ "$BUNDLE_BYTES" -gt "$LARGEST_BYTES" ]; then
      LARGEST_BYTES=$BUNDLE_BYTES
    fi
    echo "📱 App Bundle Size: $BUNDLE_SIZE"
  fi

  if [ -z "$APK_SIZE" ] && [ -z "$BUNDLE_SIZE" ]; then
    echo -e "${YELLOW}⚠️  No Android artifact found to analyze.${NC}"
  else
    echo ""

    # Analyze dependencies
    echo "📊 Analyzing dependencies..."
    flutter pub deps > /tmp/flutter_deps.txt

    # Count dependencies
    DEP_COUNT=$(grep -c "├" /tmp/flutter_deps.txt || echo "0")
    echo "   Total dependencies: $DEP_COUNT"
    echo ""

    # Analyze assets
    if [ -d "assets" ]; then
      ASSET_SIZE=$(du -sh assets 2>/dev/null | cut -f1 || echo "0")
      echo "   Assets size: $ASSET_SIZE"
    fi

    # Provide recommendations
    echo ""
    echo "💡 Optimization Recommendations:"
    echo "================================"
    echo ""

    if [ "$LARGEST_BYTES" -gt 50000000 ]; then  # 50MB
      echo -e "${YELLOW}⚠️  The Android build is larger than 50MB. Consider:${NC}"
      echo "   - Using the App Bundle instead of an APK"
      echo "   - Splitting APKs by ABI: flutter build apk --split-per-abi"
      echo "   - Removing unused assets"
      echo "   - Compressing images"
    elif [ "$LARGEST_BYTES" -gt 25000000 ]; then  # 25MB
      echo -e "${YELLOW}⚠️  The Android build is larger than 25MB. Consider:${NC}"
      echo "   - Removing unused dependencies"
      echo "   - Optimizing images"
      echo "   - Using deferred imports for large features"
    else
      echo -e "${GREEN}✅ Android build size is reasonable${NC}"
    fi

    echo ""
    echo "📋 Additional Analysis:"
    echo "   - Run 'flutter pub deps' to see dependency tree"
    echo "   - Run 'flutter analyze' to check for unused code"
    echo "   - Check 'pubspec.yaml' for unused dependencies"
    echo ""

    echo "📊 Build Size Summary:"
    echo "================================"
    if [ -n "$APK_SIZE" ]; then
      echo "APK Size: $APK_SIZE"
    fi
    if [ -n "$BUNDLE_SIZE" ]; then
      echo "App Bundle Size: $BUNDLE_SIZE"
    fi
    echo "Dependencies: $DEP_COUNT"
    echo ""
  fi
fi

# Summary
echo -e "${GREEN}All builds completed!${NC}"
echo ""
echo "Build artifacts:"
echo "  Android: build/app/outputs/"
echo "  iOS: build/ios/ipa/"
echo "  Web: build/web/"


