#!/bin/bash
set -e

# Install script for DeliVerb Audio Unit
cd "$(dirname "$0")/.."

# Build first
./scripts/build.sh

# Install AUv2 component
echo "Installing AUv2 component..."
mkdir -p ~/Library/Audio/Plug-Ins/Components
cp -r build/DeliVerb.component ~/Library/Audio/Plug-Ins/Components/

# Install AUv3 app (which contains the extension)
echo "Installing AUv3 app..."
mkdir -p ~/Applications
cp -r build/DeliVerb.app ~/Applications/

# Reset Audio Unit cache
echo "Resetting AU cache..."
killall -9 AudioComponentRegistrar 2>/dev/null || true

echo ""
echo "Installation complete!"
echo "AUv2: ~/Library/Audio/Plug-Ins/Components/DeliVerb.component"
echo "AUv3: ~/Applications/DeliVerb.app"
echo ""
echo "Restart your DAW to see the plugin."
