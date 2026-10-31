#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

SDK_PATH=$(xcrun --show-sdk-path)
APP_NAME="NotchFlow"
VERSION="1.0.0"
OUTPUT="DynamicIslandMac"

case "$1" in
  run)
    echo "🔨 Compiling $APP_NAME for local architecture..."
    swiftc -O -sdk "$SDK_PATH" -target "x86_64-apple-macos12.0" Sources/DynamicIslandMac/*.swift -o "$OUTPUT"
    echo "🚀 Launching $APP_NAME..."
    ./"$OUTPUT"
    ;;
  build)
    echo "🔨 Compiling $APP_NAME..."
    swiftc -O -sdk "$SDK_PATH" -target "x86_64-apple-macos12.0" Sources/DynamicIslandMac/*.swift -o "$OUTPUT"
    echo "✅ Successfully built: $DIR/$OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
    ;;
  universal)
    echo "🔨 Compiling Universal Binary (x86_64 + arm64)..."
    mkdir -p .build/x86_64 .build/arm64 .build/universal
    swiftc -O -sdk "$SDK_PATH" -target "x86_64-apple-macos12.0" Sources/DynamicIslandMac/*.swift -o .build/x86_64/$APP_NAME
    swiftc -O -sdk "$SDK_PATH" -target "arm64-apple-macos12.0" Sources/DynamicIslandMac/*.swift -o .build/arm64/$APP_NAME
    lipo -create -output .build/universal/$APP_NAME .build/x86_64/$APP_NAME .build/arm64/$APP_NAME
    echo "✅ Created Universal Binary: .build/universal/$APP_NAME"
    file .build/universal/$APP_NAME
    ;;
  app)
    echo "📦 Building $APP_NAME.app bundle (Universal Binary)..."
    $0 universal
    
    APP_BUNDLE="$APP_NAME.app"
    rm -rf "$APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    
    cp .build/universal/$APP_NAME "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
    cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    cp Resources/MascotHand*.png "$APP_BUNDLE/Contents/Resources/"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    
    echo "🔏 Ad-hoc code signing $APP_BUNDLE..."
    codesign --force --deep -s - "$APP_BUNDLE"
    echo "✅ $APP_BUNDLE created successfully!"
    ;;
  dmg)
    echo "💿 Creating DMG Installer for $APP_NAME $VERSION..."
    $0 app
    
    DMG_NAME="$APP_NAME-$VERSION.dmg"
    STAGING_DIR=".build/dmg_staging"
    rm -rf "$STAGING_DIR" "$DMG_NAME"
    mkdir -p "$STAGING_DIR"
    
    cp -R "$APP_NAME.app" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"
    
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"
    rm -rf "$STAGING_DIR"
    
    echo "🎉 Created DMG: $DIR/$DMG_NAME ($(du -h "$DMG_NAME" | cut -f1))"
    ;;
  clean)
    rm -rf "$OUTPUT" .build "$APP_NAME.app" "$APP_NAME-"*.dmg
    echo "🧹 Clean complete."
    ;;
  *)
    echo "Usage: ./build.sh [run | build | universal | app | dmg | clean]"
    ;;
esac
