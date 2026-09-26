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
if [ "$ANALYZE_SIZE" = true ]; then
  echo ""
  echo "🔍 Build Size Analysis"
  echo "================================"
  echo ""
  
  # Get APK size
  APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
  if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    APK_SIZE_BYTES=$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH" 2>/dev/null)
    
    echo -e "${GREEN}✅ Build completed successfully${NC}"
    echo "📱 APK Size: $APK_SIZE"
    echo ""
    
    # Analyze dependencies
    echo "📊 Analyzing dependencies..."
    flutter pub deps > /tmp/flutter_deps.txt
    
    # Count dependencies
    DEP_COUNT=$(grep -c "├" /tmp/flutter_deps.txt || echo "0")
    echo "   Total dependencies: $DEP_COUNT"
    echo ""
    
    # Check for unused dependencies (basic check)
    echo "🔍 Checking for potential optimizations..."
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
    
    # Check APK size thresholds
    if [ "$APK_SIZE_BYTES" -gt 50000000 ]; then  # 50MB
      echo -e "${YELLOW}⚠️  APK is larger than 50MB. Consider:${NC}"
      echo "   - Using App Bundle instead of APK"
      echo "   - Splitting by ABI (already done)"
      echo "   - Removing unused assets"
      echo "   - Compressing images"
    elif [ "$APK_SIZE_BYTES" -gt 25000000 ]; then  # 25MB
      echo -e "${YELLOW}⚠️  APK is larger than 25MB. Consider:${NC}"
      echo "   - Removing unused dependencies"
      echo "   - Optimizing images"
      echo "   - Using deferred imports for large features"
    else
      echo -e "${GREEN}✅ APK size is reasonable${NC}"
    fi
    
    echo ""
    echo "📋 Additional Analysis:"
    echo "   - Run 'flutter pub deps' to see dependency tree"
    echo "   - Run 'flutter analyze' to check for unused code"
    echo "   - Use 'flutter build appbundle' for Play Store (smaller size)"
    echo "   - Check 'pubspec.yaml' for unused dependencies"
    echo ""
    
    # Build app bundle for comparison (if not already built)
    if [ "$ENVIRONMENT" != "production" ] || [ ! -f "build/app/outputs/bundle/release/app-release.aab" ]; then
      echo "📦 Building App Bundle (recommended for Play Store)..."
      flutter build appbundle --release
    fi
    
    BUNDLE_PATH="build/app/outputs/bundle/release/app-release.aab"
    if [ -f "$BUNDLE_PATH" ]; then
      BUNDLE_SIZE=$(du -h "$BUNDLE_PATH" | cut -f1)
      echo -e "${GREEN}✅ App Bundle created${NC}"
      echo "📱 App Bundle Size: $BUNDLE_SIZE"
      echo ""
      echo "💡 App Bundle is typically 20-30% smaller than APK"
    fi
    
    echo ""
    echo "📊 Build Size Summary:"
    echo "================================"
    echo "APK Size: $APK_SIZE"
    if [ -f "$BUNDLE_PATH" ]; then
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


