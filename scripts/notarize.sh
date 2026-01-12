#!/bin/bash

# DeliVerb Notarization Script
# Submits the installer to Apple for notarization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source .env file if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi
OUT_DIR="$PROJECT_DIR/out"

# Read version from package.json
VERSION=$(node -p "require('$PROJECT_DIR/package.json').version")
if [ -z "$VERSION" ]; then
    VERSION="1.0.0"
    echo "Warning: Could not read version from package.json, using default: $VERSION"
fi

PKG_PATH="$OUT_DIR/DeliVerb-$VERSION.pkg"
BUNDLE_ID="com.deliverb.audiounit"

# These must be set as environment variables
# APPLE_ID: Your Apple ID email
# APPLE_APP_PASSWORD: App-specific password (not your Apple ID password)
# APPLE_TEAM_ID: Your Team ID (found in Apple Developer portal)

if [ -z "$APPLE_ID" ] || [ -z "$APPLE_APP_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
    echo "Error: Required environment variables not set."
    echo ""
    echo "Please set the following:"
    echo "  export APPLE_ID='your@email.com'"
    echo "  export APPLE_APP_PASSWORD='xxxx-xxxx-xxxx-xxxx'"
    echo "  export APPLE_TEAM_ID='XXXXXXXXXX'"
    echo ""
    echo "See README.md for instructions on obtaining these."
    exit 1
fi

if [ ! -f "$PKG_PATH" ]; then
    echo "Error: Installer not found at $PKG_PATH"
    echo "Run build-installer.sh first."
    exit 1
fi

echo "=========================================="
echo "DeliVerb Notarization"
echo "=========================================="
echo ""
echo "Submitting to Apple for notarization..."
echo "This may take several minutes..."
echo ""

# Submit for notarization
xcrun notarytool submit "$PKG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

# Check the result
echo ""
echo "Checking notarization status..."
NOTARIZATION_INFO=$(xcrun notarytool history \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" | head -5)

echo "$NOTARIZATION_INFO"

# Staple the notarization ticket to the installer
echo ""
echo "Stapling notarization ticket..."
xcrun stapler staple "$PKG_PATH"

echo ""
echo "=========================================="
echo "Notarization complete!"
echo ""
echo "Your installer is now ready for distribution:"
echo "  $PKG_PATH"
echo ""
echo "Users can install it without Gatekeeper warnings."
echo "=========================================="
