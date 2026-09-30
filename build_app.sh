#!/bin/zsh
set -euo pipefail

APP_NAME="IllBeBack"
DISPLAY_NAME="I'll Be Back"
BUNDLE_ID="com.illbeback.app"
VERSION="1.0.0"
BUILD_NUMBER="1"
APP_BUNDLE="${APP_NAME}.app"
APP_STORE_MODE=false

for arg in "$@"; do
    if [[ "$arg" == "--app-store" ]]; then
        APP_STORE_MODE=true
    fi
done

echo "🕶️ Building ${DISPLAY_NAME} (App Store Mode: ${APP_STORE_MODE})..."

if [[ "$APP_STORE_MODE" == "true" ]]; then
    swift build -c release -Xswiftc -DAPP_STORE
else
    swift build -c release
fi

BIN_PATH=$(swift build -c release --show-bin-path)
EXECUTABLE_PATH="${BIN_PATH}/${APP_NAME}"

# Generate AppIcon.icns if not present
mkdir -p Resources
if [[ ! -f "Resources/AppIcon.icns" ]]; then
    echo "🎨 Generating Cyber-Visor AppIcon.icns..."
    ICONSET_DIR="Resources/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    swift Scripts/generate_icon.swift "Resources/icon_1024.png"
    sips -z 256 256   "Resources/icon_1024.png" --out "Resources/icon_preview.png" >/dev/null

    sips -z 16 16     "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
    sips -z 32 32     "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
    sips -z 32 32     "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
    sips -z 64 64     "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
    sips -z 128 128   "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
    sips -z 256 256   "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
    sips -z 512 512   "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "Resources/icon_1024.png" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
    cp "Resources/icon_1024.png" "${ICONSET_DIR}/icon_512x512@2x.png"

    iconutil -c icns "$ICONSET_DIR" -o "Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR" "Resources/icon_1024.png"
fi

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "$EXECUTABLE_PATH" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

if [[ -f "Resources/AppIcon.icns" ]]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Anatoli Aliaksandrou. All rights reserved.</string>
</dict>
</plist>
EOF

if [[ "$APP_STORE_MODE" == "true" ]]; then
    codesign --force --deep --sign - --entitlements AppStore.entitlements "$APP_BUNDLE"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

touch "$APP_BUNDLE"
echo "✅ Packaged ${APP_BUNDLE} successfully!"
