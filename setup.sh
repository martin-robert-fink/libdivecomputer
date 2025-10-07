#!/bin/bash

# Libdivecomputer Flutter Plugin - Setup Script
# Run this after extracting the archive and adding your xcframework

set -e

echo "================================================="
echo "Libdivecomputer Flutter Plugin - Setup"
echo "================================================="
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found"
    echo "Please run this script from the plugin root directory"
    exit 1
fi

echo "✓ Found plugin root directory"
echo ""

# Check for xcframework on iOS
if [ ! -d "ios/Frameworks/libdivecomputer.xcframework" ]; then
    echo "⚠️  Warning: ios/Frameworks/libdivecomputer.xcframework not found"
    echo "   You need to copy your pre-built xcframework to:"
    echo "   ios/Frameworks/libdivecomputer.xcframework/"
    echo ""
fi

# Check for xcframework on macOS
if [ ! -d "macos/Frameworks/libdivecomputer.xcframework" ]; then
    echo "⚠️  Warning: macos/Frameworks/libdivecomputer.xcframework not found"
    echo "   You need to copy your pre-built xcframework to:"
    echo "   macos/Frameworks/libdivecomputer.xcframework/"
    echo ""
fi

# Install plugin dependencies
echo "📦 Installing plugin dependencies..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Failed to install plugin dependencies"
    exit 1
fi

echo "✓ Plugin dependencies installed"
echo ""

# Install example dependencies
echo "📦 Installing example app dependencies..."
cd example
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Failed to install example dependencies"
    exit 1
fi

cd ..
echo "✓ Example dependencies installed"
echo ""

# Run analysis
echo "🔍 Running flutter analyze..."
flutter analyze

if [ $? -ne 0 ]; then
    echo "⚠️  Analysis found issues (may be due to missing xcframework)"
else
    echo "✓ Analysis passed"
fi
echo ""

echo "================================================="
echo "Setup Complete!"
echo "================================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Copy your libdivecomputer.xcframework to:"
echo "   - ios/Frameworks/libdivecomputer.xcframework/"
echo "   - macos/Frameworks/libdivecomputer.xcframework/"
echo ""
echo "2. Configure Info.plist files (see example/INFO_PLIST_CONFIG.md)"
echo ""
echo "3. Run the example app:"
echo "   cd example"
echo "   flutter run -d macos    # Run from Terminal, not VSCode!"
echo ""
echo "4. See README.md for complete documentation"
echo ""
echo "================================================="
