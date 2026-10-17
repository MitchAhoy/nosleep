#!/bin/bash
# Build NoSleep.app, install it to /Applications and launch it.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="NoSleep"
BUNDLE_ID="com.mitch.nosleep"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

echo "==> Compiling (release)"
rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS"

# Work around a known Command Line Tools upgrade bug: a stale
# usr/include/swift/module.modulemap duplicates bridging.modulemap and breaks
# every import ("redefinition of module 'SwiftBridging'"). Rather than deleting
# it with sudo, hide it from the compiler with a VFS overlay.
EXTRA_FLAGS=()
CLT_SWIFT_INC="$(xcode-select -p)/usr/include/swift"
if [[ -f "$CLT_SWIFT_INC/module.modulemap" && -f "$CLT_SWIFT_INC/bridging.modulemap" ]]; then
    : > "$BUILD_DIR/empty.modulemap"
    cat > "$BUILD_DIR/vfs-overlay.yaml" <<EOF
{ "version": 0, "case-sensitive": "false", "roots": [ { "type": "file",
  "name": "$CLT_SWIFT_INC/module.modulemap",
  "external-contents": "$PWD/$BUILD_DIR/empty.modulemap" } ] }
EOF
    EXTRA_FLAGS=(-vfsoverlay "$BUILD_DIR/vfs-overlay.yaml" -Xcc -ivfsoverlay -Xcc "$BUILD_DIR/vfs-overlay.yaml")
fi

swiftc -O -swift-version 5 \
    -target arm64-apple-macos13.0 \
    "${EXTRA_FLAGS[@]}" \
    -framework AppKit -framework IOKit -framework ServiceManagement \
    Sources/main.swift \
    -o "$APP/Contents/MacOS/$APP_NAME"

echo "==> Writing Info.plist"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"

echo "==> Quitting any running instance"
if pgrep -x "$APP_NAME" >/dev/null; then
    pkill -x "$APP_NAME" || true
    for _ in {1..50}; do
        pgrep -x "$APP_NAME" >/dev/null || break
        sleep 0.1
    done
fi

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "==> Launching"
open "$DEST"
echo "Done."
