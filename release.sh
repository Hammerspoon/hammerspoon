#!/usr/bin/env bash

set -e

# build app
xcodebuild clean build
VERSION=$(defaults read "$(pwd)/Hydra/Hydra-Info" CFBundleVersion)
FILENAME="Hydra-$VERSION.app.zip"

# build .zip
rm -rf "$FILENAME"
zip "$FILENAME" build/Release/Hydra.app
echo "Created $FILENAME"
