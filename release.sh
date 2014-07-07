#!/usr/bin/env bash

set -e

# build app
xcodebuild clean build
VERSION=$(defaults read "$(pwd)/Hydra/XcodeCrap/Hydra-Info" CFBundleVersion)
FILENAME="Hydra-$VERSION.app.zip"

# build .zip
rm -rf "$FILENAME"
pushd build/Release/
zip -r "../../$FILENAME" Hydra.app
popd
echo "Created $FILENAME"
