#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

SDK_PATH=$(xcrun --show-sdk-path)
TARGET="x86_64-apple-macos12.0"
OUTPUT="DynamicIslandMac"

case "$1" in
  run)
    echo "🔨 Compiling Dynamic Island..."
    swiftc -O -sdk "$SDK_PATH" -target "$TARGET" Sources/DynamicIslandMac/*.swift -o "$OUTPUT"
    echo "🚀 Launching Dynamic Island..."
    ./"$OUTPUT"
    ;;
  build)
    echo "🔨 Compiling Dynamic Island..."
    swiftc -O -sdk "$SDK_PATH" -target "$TARGET" Sources/DynamicIslandMac/*.swift -o "$OUTPUT"
    echo "✅ Successfully built: $DIR/$OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
    ;;
  clean)
    rm -f "$OUTPUT"
    echo "🧹 Clean complete."
    ;;
  *)
    echo "Usage: ./build.sh [run | build | clean]"
    ;;
esac

