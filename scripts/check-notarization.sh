#!/bin/bash
#
# Check notarization status and staple if approved
#

SUBMISSION_ID="4cbd9f53-3885-4cab-82ef-ea0dd3cc32a2"
PROFILE="TwinKley-Notary"
APP_PATH="$HOME/Applications/TwinKley.app"

echo "Checking notarization status..."
echo ""

INFO=$(xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "$PROFILE" 2>&1)
echo "$INFO"
echo ""

STATUS=$(echo "$INFO" | grep "status:" | awk '{print $2}')

case "$STATUS" in
    "Accepted")
        echo "✅ Notarization approved!"
        echo ""
        echo "Stapling notarization ticket to app..."
        xcrun stapler staple "$APP_PATH"
        echo ""
        echo "✅ App is now fully notarized and ready for distribution!"
        echo ""
        echo "Verify:"
        spctl -a -vvv "$APP_PATH"
        ;;
    "Invalid")
        echo "❌ Notarization failed."
        echo ""
        echo "Getting failure log..."
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$PROFILE"
        ;;
    "In Progress")
        echo "⏳ Still processing. Check again in a few minutes."
        echo ""
        echo "Run this script again: ./scripts/check-notarization.sh"
        ;;
    *)
        echo "Unknown status: $STATUS"
        ;;
esac
