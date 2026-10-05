#!/bin/bash

set -euo pipefail

APP_PATH="${1:?Usage: $0 <path/to/ADB-Studio.app>}"
IDENTITY="${DEVELOPER_ID_IDENTITY:-Developer ID Application}"
ENTITLEMENTS="$(cd "$(dirname "$0")/.." && pwd)/ADB-Studio/ADB_Studio.entitlements"

sign() {
    codesign --force --timestamp --options runtime --sign "${IDENTITY}" "$@"
}

echo "🔏 Signing nested code..."

while IFS= read -r -d '' item; do
    echo "   ${item#"${APP_PATH}/"}"
    sign "${item}"
done < <(find "${APP_PATH}/Contents" -depth \( -name "*.framework" -o -name "*.dylib" -o -name "*.xpc" -o -name "*.appex" -o -name "*.app" \) -print0)

echo "🔏 Signing $(basename "${APP_PATH}")..."
sign --entitlements "${ENTITLEMENTS}" "${APP_PATH}"

echo "🔍 Verifying signature..."
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

SIGNATURE_INFO="$(codesign --display --verbose=2 "${APP_PATH}" 2>&1)"
echo "${SIGNATURE_INFO}" | grep -E "^(Authority|TeamIdentifier|Timestamp)=|flags="

if ! echo "${SIGNATURE_INFO}" | grep -q "^Authority=Developer ID Application"; then
    echo "❌ ${APP_PATH} is not signed with a Developer ID Application identity — notarization would reject it." >&2
    exit 1
fi

echo "✅ Signed: ${APP_PATH}"
