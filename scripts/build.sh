#!/usr/bin/env bash
# Mochi — universal (arm64 + x86_64) .app bundle.
# Works with just Command Line Tools (no full Xcode needed):
# cross-compiles both arches with swiftc and merges with lipo.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

echo "==> swiftc release, arm64 + x86_64"
mkdir -p .build/universal
swiftc -O -target arm64-apple-macos13.0 Sources/Mochi/*.swift -o .build/universal/Mochi-arm64
swiftc -O -target x86_64-apple-macos13.0 Sources/Mochi/*.swift -o .build/universal/Mochi-x86_64
lipo -create -output .build/universal/Mochi .build/universal/Mochi-arm64 .build/universal/Mochi-x86_64
lipo -info .build/universal/Mochi

BIN=".build/universal/Mochi"

APP="$ROOT/Mochi.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/sounds" "$APP/Contents/Resources/fonts"

cp "$BIN" "$APP/Contents/MacOS/Mochi"
cp Assets/sounds/*.wav "$APP/Contents/Resources/sounds/"
cp Assets/fonts/PressStart2P-Regular.ttf "$APP/Contents/Resources/fonts/"
cp Assets/fonts/OFL.txt "$APP/Contents/Resources/fonts/" 2>/dev/null || true

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Mochi</string>
    <key>CFBundleIdentifier</key><string>dev.tryouts.mochi</string>
    <key>CFBundleName</key><string>Mochi</string>
    <key>CFBundleDisplayName</key><string>Mochi</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> icon"
ICONSET="$(mktemp -d)/Mochi.iconset"
mkdir -p "$ICONSET"
"$APP/Contents/MacOS/Mochi" --make-icon "$ICONSET/icon_512x512.png" 512
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" "$ICONSET/icon_512x512.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z "$d" "$d" "$ICONSET/icon_512x512.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> codesign (ad-hoc)"
codesign --force --sign - "$APP"

echo "==> done: $APP"
ls -la "$APP/Contents/MacOS"