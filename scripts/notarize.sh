#!/bin/bash

set -euo pipefail

TARGET="${1:?Usage: $0 <path/to/ADB-Studio.app | path/to/file.dmg>}"

if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    AUTH=(--keychain-profile "${NOTARY_KEYCHAIN_PROFILE}")
elif [ -n "${NOTARY_API_KEY_PATH:-}" ] && [ -n "${NOTARY_API_KEY_ID:-}" ] && [ -n "${NOTARY_API_ISSUER_ID:-}" ]; then
    AUTH=(--key "${NOTARY_API_KEY_PATH}" --key-id "${NOTARY_API_KEY_ID}" --issuer "${NOTARY_API_ISSUER_ID}")
else
    echo "❌ No notary credentials: set NOTARY_KEYCHAIN_PROFILE, or NOTARY_API_KEY_PATH + NOTARY_API_KEY_ID + NOTARY_API_ISSUER_ID." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

case "${TARGET}" in
    *.app)
        UPLOAD="${WORK_DIR}/$(basename "${TARGET}" .app).zip"
        ditto -c -k --keepParent "${TARGET}" "${UPLOAD}"
        ;;
    *.dmg)
        UPLOAD="${TARGET}"
        ;;
    *)
        echo "❌ Unsupported artifact (expected .app or .dmg): ${TARGET}" >&2
        exit 1
        ;;
esac

echo "📤 Submitting $(basename "${TARGET}") to the notary service..."
RESULT="${WORK_DIR}/result.json"
xcrun notarytool submit "${UPLOAD}" "${AUTH[@]}" --wait --timeout 30m --output-format json > "${RESULT}" || true

STATUS="$(plutil -extract status raw -o - "${RESULT}" 2> /dev/null || echo "Unknown")"
SUBMISSION_ID="$(plutil -extract id raw -o - "${RESULT}" 2> /dev/null || echo "")"
echo "Notarization status: ${STATUS} (submission ${SUBMISSION_ID:-n/a})"

if [ "${STATUS}" != "Accepted" ]; then
    cat "${RESULT}" >&2
    if [ -n "${SUBMISSION_ID}" ]; then
        echo "📜 Notary log:" >&2
        xcrun notarytool log "${SUBMISSION_ID}" "${AUTH[@]}" >&2 || true
    fi
    exit 1
fi

echo "📎 Stapling ticket..."
xcrun stapler staple "${TARGET}"
xcrun stapler validate "${TARGET}"

echo "🛡️ Gatekeeper assessment..."
case "${TARGET}" in
    *.app) spctl --assess --type execute --verbose=2 "${TARGET}" ;;
    *.dmg) spctl --assess --type open --context context:primary-signature --verbose=2 "${TARGET}" ;;
esac

echo "✅ Notarized and stapled: ${TARGET}"
