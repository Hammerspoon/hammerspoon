#!/usr/bin/env bash

set -e

# build app
xcodebuild clean build
VERSION=$(defaults read "$(pwd)/Hydra/Hydra-Info" CFBundleVersion)
FILENAME="Hydra-$VERSION.app.zip"

# build .zip
rm -rf "$FILENAME"
pushd build/Release/
zip "../../$FILENAME" Hydra.app
popd
echo "Created $FILENAME"
