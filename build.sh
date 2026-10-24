#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

SDK_PATH=$(xcrun --show-sdk-path)
TARGET="x86_64-apple-macos12.0"
OUTPUT="DynamicIslandMac"

case "$1" in
  run)
    echo "🔨 Mengompilasi Dynamic Island..."
    swiftc -O -sdk "$SDK_PATH" -target "$TARGET" Sources/DynamicIslandMac/*.swift -o "$OUTPUT"
    echo "🚀 Menjalankan Dynamic Island di layar atas..."
    ./"$OUTPUT"
    ;;
  build)
    echo "🔨 Mengompilasi Dynamic Island..."
    swiftc -O -sdk "$SDK_PATH" -target "$TARGET" Sources/DynamicIslandMac/*.swift -o "$OUTPUT"
    echo "✅ Berhasil dikompilasi: $DIR/$OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
    ;;
  clean)
    rm -f "$OUTPUT"
    echo "🧹 Clean selesai."
    ;;
  *)
    echo "Gunakan: ./build.sh [run | build | clean]"
    ;;
esac

