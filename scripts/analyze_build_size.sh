#!/bin/bash

# Build Size Analysis Script
# This script analyzes the Flutter app build size and provides optimization recommendations

set -e

echo "🔍 Flutter Build Size Analysis"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Build the app in release mode
echo "📦 Building release APK..."
flutter build apk --release --split-per-abi

# Get APK size
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    APK_SIZE_BYTES=$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH" 2>/dev/null)
    
    echo ""
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
    
    # Build app bundle for comparison
    echo "📦 Building App Bundle (recommended for Play Store)..."
    flutter build appbundle --release
    
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
    echo "✅ Analysis complete!"
    
else
    echo -e "${RED}Error: APK not found at $APK_PATH${NC}"
    exit 1
fi

