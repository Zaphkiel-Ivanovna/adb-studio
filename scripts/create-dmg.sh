#!/bin/bash

set -e

APP_NAME="ADB-Studio"
BUNDLE_ID="dev.zaphkiel.adbstudio"
DMG_NAME="${APP_NAME}"
DMG_DIR="build/dmg"
BUILD_DIR="build/Release"
VOLUME_NAME="${APP_NAME}"

echo "🔨 Building ${APP_NAME}..."

# Clean and build
xcodebuild -scheme "${APP_NAME}" -configuration Release -derivedDataPath build clean build

# Copy app to build directory
mkdir -p "${BUILD_DIR}"
cp -R "build/Build/Products/Release/${APP_NAME}.app" "${BUILD_DIR}/"

echo "📦 Creating DMG..."

# Clean previous DMG
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_DIR}"

# Create DMG contents
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DMG_DIR}/"

# Create symlink to Applications
ln -s /Applications "${DMG_DIR}/Applications"

# Create temporary DMG
TEMP_DMG="build/${DMG_NAME}-temp.dmg"
FINAL_DMG="build/${DMG_NAME}.dmg"

rm -f "${TEMP_DMG}" "${FINAL_DMG}"

hdiutil create -srcfolder "${DMG_DIR}" -volname "${VOLUME_NAME}" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW "${TEMP_DMG}"

# Mount DMG
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "${TEMP_DMG}" -readwrite -noverify -noautoopen

# Wait for mount
sleep 2

# Configure DMG window with AppleScript
echo "🎨 Configuring DMG appearance..."

osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 920, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set position of item "${APP_NAME}.app" of container window to {130, 180}
        set position of item "Applications" of container window to {390, 180}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount
sync
hdiutil detach "${MOUNT_DIR}"

# Convert to compressed DMG
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${FINAL_DMG}"

# Clean up
rm -f "${TEMP_DMG}"
rm -rf "${DMG_DIR}"

echo "✅ DMG created: ${FINAL_DMG}"
echo "📊 Size: $(du -h "${FINAL_DMG}" | cut -f1)"
