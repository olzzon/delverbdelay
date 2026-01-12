#!/bin/bash
set -e

# Build script for DeliVerb Audio Unit
cd "$(dirname "$0")/.."

# Get version from package.json
VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "1.0.0")
echo "Building DeliVerb v$VERSION"

# Create build directory
mkdir -p build
cd build

# Configure with CMake
cmake .. -DCMAKE_BUILD_TYPE=Release -DPROJECT_VERSION="$VERSION"

# Build
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

echo ""
echo "Build complete!"
echo "AUv2 Component: build/DeliVerb.component"
echo "AUv3 App: build/DeliVerb.app"
