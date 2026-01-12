#!/bin/bash

# DeliVerb Installer Builder
# Creates a signed .pkg installer for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
OUT_DIR="$PROJECT_DIR/out"
INSTALLER_DIR="$BUILD_DIR/installer"

# Read version from package.json
VERSION=$(node -p "require('$PROJECT_DIR/package.json').version")
if [ -z "$VERSION" ]; then
    VERSION="1.0.0"
    echo "Warning: Could not read version from package.json, using default: $VERSION"
fi

PRODUCT_NAME="DeliVerb"
BUNDLE_ID="com.deliverb.audiounit"

# Load environment variables from .env file if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Code signing identity (set these for signed builds)
# Find your identities with: security find-identity -v -p codesigning
DEVELOPER_ID_APP="${DEVELOPER_ID_APPLICATION:-}"  # "Developer ID Application: Your Name (XXXXXXXXXX)"
DEVELOPER_ID_INSTALLER="${DEVELOPER_ID_INSTALLER:-}"  # "Developer ID Installer: Your Name (XXXXXXXXXX)"

echo "=========================================="
echo "DeliVerb Installer Builder"
echo "Version: $VERSION"
echo "=========================================="

# Clean and create directories
rm -rf "$INSTALLER_DIR"
mkdir -p "$INSTALLER_DIR/payload/Library/Audio/Plug-Ins/Components"
mkdir -p "$INSTALLER_DIR/scripts"
mkdir -p "$INSTALLER_DIR/resources"
mkdir -p "$OUT_DIR"

# Build the plugin using Xcode generator
echo ""
echo "Building plugin..."
# Clean build directory to avoid generator conflicts
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake -G Xcode "$PROJECT_DIR"
xcodebuild -project DeliVerb.xcodeproj -scheme DeliVerbAUv2 -configuration Release build 2>&1 | grep -E "(BUILD|error:|warning:)" | head -20

# Recreate installer directories (they were inside build which we deleted)
mkdir -p "$INSTALLER_DIR/payload/Library/Audio/Plug-Ins/Components"
mkdir -p "$INSTALLER_DIR/scripts"
mkdir -p "$INSTALLER_DIR/resources"

# Copy the built component
echo ""
echo "Preparing installer payload..."
cp -R "$BUILD_DIR/Release/DeliVerb.component" "$INSTALLER_DIR/payload/Library/Audio/Plug-Ins/Components/"

# Code sign the plugin if identity is provided
if [ -n "$DEVELOPER_ID_APP" ]; then
    echo ""
    echo "Code signing plugin with: $DEVELOPER_ID_APP"
    codesign --force --options runtime --timestamp \
        --sign "$DEVELOPER_ID_APP" \
        "$INSTALLER_DIR/payload/Library/Audio/Plug-Ins/Components/DeliVerb.component"

    echo "Verifying signature..."
    codesign --verify --verbose "$INSTALLER_DIR/payload/Library/Audio/Plug-Ins/Components/DeliVerb.component"
else
    echo ""
    echo "WARNING: No code signing identity provided."
    echo "Set DEVELOPER_ID_APPLICATION environment variable for signed builds."
fi

# Create postinstall script to refresh AU cache
cat > "$INSTALLER_DIR/scripts/postinstall" << 'POSTINSTALL'
#!/bin/bash
# Refresh Audio Unit cache after installation
killall -9 AudioComponentRegistrar 2>/dev/null || true
exit 0
POSTINSTALL
chmod +x "$INSTALLER_DIR/scripts/postinstall"

# Create welcome text
cat > "$INSTALLER_DIR/resources/welcome.txt" << 'WELCOME'
Welcome to DeliVerb

DeliVerb is a versatile delay-reverb Audio Unit plugin with ducking capabilities, creating rich atmospheric effects.

Features:
- Combined Delay and Reverb with separate mix controls
- Style control from Classic to Atmospheric
- Low Cut and High Cut filters for both Delay and Reverb
- Intelligent ducking with adjustable behaviour
- Deep blue metallic pedal-style interface

This installer will place the plugin in:
/Library/Audio/Plug-Ins/Components/

After installation, restart your DAW to see the plugin.
WELCOME

# Create license text
cat > "$INSTALLER_DIR/resources/license.txt" << 'LICENSE'
DeliVerb Audio Unit Plugin
Copyright. All rights reserved.

This software is proprietary and confidential.
Unauthorized copying, distribution, or use is strictly prohibited.

By installing this software, you agree to these terms.
LICENSE

# Build the component package
echo ""
echo "Building component package..."
pkgbuild \
    --root "$INSTALLER_DIR/payload" \
    --scripts "$INSTALLER_DIR/scripts" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/" \
    "$INSTALLER_DIR/DeliVerb-component.pkg"

# Create distribution XML
cat > "$INSTALLER_DIR/distribution.xml" << DISTXML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>DeliVerb</title>
    <organization>com.deliverb</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="true" rootVolumeOnly="true"/>

    <welcome file="welcome.txt"/>
    <license file="license.txt"/>

    <choices-outline>
        <line choice="default">
            <line choice="com.deliverb.audiounit"/>
        </line>
    </choices-outline>

    <choice id="default"/>
    <choice id="com.deliverb.audiounit" visible="false">
        <pkg-ref id="com.deliverb.audiounit"/>
    </choice>

    <pkg-ref id="com.deliverb.audiounit" version="$VERSION" onConclusion="none">DeliVerb-component.pkg</pkg-ref>
</installer-gui-script>
DISTXML

# Build the product archive
echo ""
echo "Building product archive..."
productbuild \
    --distribution "$INSTALLER_DIR/distribution.xml" \
    --resources "$INSTALLER_DIR/resources" \
    --package-path "$INSTALLER_DIR" \
    "$INSTALLER_DIR/DeliVerb-unsigned.pkg"

# Sign the installer if identity is provided
OUTPUT_PKG="$OUT_DIR/DeliVerb-$VERSION.pkg"
if [ -n "$DEVELOPER_ID_INSTALLER" ]; then
    echo ""
    echo "Signing installer with: $DEVELOPER_ID_INSTALLER"
    productsign \
        --sign "$DEVELOPER_ID_INSTALLER" \
        "$INSTALLER_DIR/DeliVerb-unsigned.pkg" \
        "$OUTPUT_PKG"

    echo "Verifying installer signature..."
    pkgutil --check-signature "$OUTPUT_PKG"
else
    cp "$INSTALLER_DIR/DeliVerb-unsigned.pkg" "$OUTPUT_PKG"
    echo ""
    echo "WARNING: Installer is not signed."
    echo "Set DEVELOPER_ID_INSTALLER environment variable for signed installers."
fi

echo ""
echo "=========================================="
echo "Installer created successfully!"
echo ""
echo "Output: $OUTPUT_PKG"
echo ""
if [ -z "$DEVELOPER_ID_APP" ] || [ -z "$DEVELOPER_ID_INSTALLER" ]; then
    echo "NOTE: For distribution, you need to:"
    echo "  1. Sign the plugin and installer"
    echo "  2. Notarize with Apple"
    echo ""
fi
echo "=========================================="
